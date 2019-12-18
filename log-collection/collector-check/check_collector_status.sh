#!/bin/bash
{

echo "Node: $(hostname -f)  Timestamp: $(date +%Z_%H:%M:%S-%d-%m-%Y)" 
pidof systemd && export PSYSMD="SYSTEMD" || export PSYSMD="SYSVINIT"
echo "$PSYSMD is detected"

if [ "$PSYSMD" == "SYSVINIT" ]; then
  FILEBEAT_PS=`ps -ef |grep filebeat |grep pid |wc -l`
  TELEGRAF_PS=`ps -ef |grep telegraf |grep pid |wc -l`
elif [ "$PSYSMD" == "SYSTEMD" ]; then
  FILEBEAT_PS=`ps -ef |grep filebeat |grep -iv grep |wc -l`
  TELEGRAF_PS=`ps -ef |grep telegraf |grep -iv grep |wc -l`
else
  echo "no able to determine system manager" && exit
fi
  
FILEBEAT_CMD=`ps -ef |grep filebeat |grep -iv pid |grep -iv grep |wc -l`
FILEBEAT_PID_FILE="/var/run/filebeat.pid"
TELEGRAF_PID_FILE="/var/run/telegraf/telegraf.pid"
#FILEBEAT_PID=`cat $FILEBEAT_PID_FILE`
#TELEGRAF_PID=`cat $TELEGRAF_PID_FILE`
FILEBEAT_PORT=`cat /etc/filebeat/filebeat.yml |grep "http.port:" |awk '{print $2}'`
PROXY_HOST=`cat /etc/filebeat/filebeat.yml |grep "hosts:" |awk '{print $2}' |sed -e 's/\"//g'`
PROXY_PROTOCOL=`cat /etc/filebeat/filebeat.yml  |grep "protocol:" |awk '{print $2}' |sed -e 's/\"//g'`
FILEBEAT_HOST_DEFAULT="http://localhost"

tpfun () {
   if [ `crontab -l |grep curl |grep filebeat |wc -l` -eq 1 ]; then
      PUSHGATEWAY_URL=`crontab -l |cut -d"|" -f2 |grep -o 'https*://[^"]*' |awk '{print $1}' |cut -d"/" -f1-4`
      TELEGRAF_PORT=`crontab -l |awk '{print $8}' |cut -d":" -f3 |cut -d"/" -f1 |sed '/^$/d'`
      TELEGRAF_URL=`crontab -l |awk '{print $8}' |sed '/^$/d'`
   else
      echo "the cron job for pushing metrics to pushgateway does not exist"
      PUSHGATEWAY_URL="NOT_DEFINED"
      TELEGRAF_PORT_DEFAULT=`cat  /etc/telegraf/telegraf.d/20-dashbase.conf |grep listen |awk '{print $3}' |sed 's/\"//g' |cut -d":" -f2`
      TELEGRAF_HOST_DEFAULT="http://localhost"
   fi
}


#check crontab  to extract telegraf URL and pushgateway URL
if [ $(ps -ef |grep cron |grep -iv grep |wc -l) -eq 1 ]; then
   tpfun
else
   #echo "cron is not running"
   tpfun
fi

echo -e '\r'

# Check filebeat process
if [ $FILEBEAT_PS -eq 1 ]; then
   echo "filebeat is running"
else
   echo "filebeat is not running"
fi

# Check filebeat PID file
if [ -f $FILEBEAT_PID_FILE ]; then
   echo " -- filebeat pid file exists"
   echo " -- filebeat process id = `cat $FILEBEAT_PID_FILE`"
else
   echo " -- filebeat pid file doesn't exist"
   FILEBEAT_PID_NOFILE=`ps -ef |grep filebeat |grep -iv grep |awk '{ print $2}'`
   echo " -- filebeat process id = $FILEBEAT_PID_NOFILE" 
fi

# Check filebeat cmd
if (( $FILEBEAT_CMD >= 1 )); then
   echo " -- $FILEBEAT_CMD filebeat command is running"
else
   echo " -- no filebeat command is running"
fi

# Check number of errors in filebeat
if [ -f "/var/log/filebeat/filebeat" ]; then 
   echo " -- number of errors in filebeat log file = $(cat /var/log/filebeat/filebeat |grep ERR |wc -l) "
else
   echo " -- /var/log/filebeat/filebeat file doesn't exist"
fi

# checking local filebeat port by curl 
if [ $(curl -k -s -o /dev/null -w "%{http_code}" ${FILEBEAT_HOST_DEFAULT}:${FILEBEAT_PORT}) -eq 200 ]; then
   echo " -- local filebeat URL ${FILEBEAT_HOST_DEFAULT}:${FILEBEAT_PORT} is accessible"
else 
   echo " -- local filebeat URL ${FILEBEAT_HOST_DEFAULT}:${FILEBEAT_PORT} is not accessible"
fi

echo -e '\r'

# Check telegraf process
if [ $TELEGRAF_PS -eq 1 ]; then
   echo "telegraf is running"
else
   echo "telegraf is not running"
fi

# Check telegraf PID file
if [ -f $TELEGRAF_PID_FILE ]; then
   echo " -- telegraf pid file exists"
   echo " -- telegraf process id  = `cat $TELEGRAF_PID_FILE`"
else
   echo " -- telegraf pid file doesn't exist"
   TELEGRAF_PID_NOFILE=`ps -ef |grep telegraf |grep -iv grep |awk '{ print $2}'`
   echo " -- telegraf process id = $TELEGRAF_PID_NOFILE"
fi

# Check number of errors in telegraf log file
if [ -f "/var/log/telegraf/telegraf.log" ]; then 
   echo " -- number of errors in telegraf.log file = $(cat /var/log/telegraf/telegraf.log |grep Error |wc -l) "
else
   echo " -- /var/log/telegraf/telegraf.log file doesn't  exist"
fi

# checking telegraf URL 
if [ ${PUSHGATEWAY_URL} == "NOT_DEFINED" ]; then
   echo " -- Since no cronjob defined for metrics; use telegraf default host:port ${TELEGRAF_HOST_DEFAULT}:${TELEGRAF_PORT_DEFAULT}/metrics "

   if [ $(curl -k -s -o /dev/null -w "%{http_code}" ${TELEGRAF_HOST_DEFAULT}:${TELEGRAF_PORT_DEFAULT}/metrics) -eq 200 ]; then
      echo " -- telegraf URL ${TELEGRAF_HOST_DEFAULT}:${TELEGRAF_PORT_DEFAULT}/metrics is accessible"
   else 
      echo " -- telegraf URL ${TELEGRAF_HOST_DEFAULT}:${TELEGRAF_PORT_DEFAULT}/metrics is not accessible"
   fi
else
   # checking telegraf URL	
   if [ $(curl -k -s -o /dev/null -w "%{http_code}" $TELEGRAF_URL) -eq 200 ]; then
      echo " -- telegraf URL $TELEGRAF_URL is accessible"
   else 
      echo " -- telegraf URL $TELEGRAF_URL is not accessible"
   fi
   # checking pushgateway URL
   if [ $(curl -k -s -o /dev/null -w "%{http_code}" $PUSHGATEWAY_URL)  -eq 200 ]; then
      echo " -- pushgateway URL $PUSHGATEWAY_URL is accessible"
   else 
      echo " -- pushgateway URL $PUSHGATEWAY_URL is not accessible"
   fi
fi

# checking proxy URL
if [ $(curl -k -s -o /dev/null -w "%{http_code}" ${PROXY_PROTOCOL}://${PROXY_HOST}) -eq 200 ]; then
   echo " -- proxy URL "$PROXY_PROTOCOL"://"$PROXY_HOST" is accessible" ; echo -e '\r'
else 
   echo " -- proxy URL "$PROXY_PROTOCOL"://"$PROXY_HOST" is not accessible" ; echo -e '\r'
fi

#check crontab, to find out if any cronjob defined to push metrics to pushgateway 
if [ $(ps -ef |grep cron |grep -iv grep |wc -l) -eq 1 ]; then
   echo "cron daemon is running"
   if [ `crontab -l |grep curl |grep filebeat |wc -l` -eq 1 ]; then
      echo "the cron job for push metrics to pushigateway is below"
      crontab -l |grep curl |grep filebeat
   else
      echo "However the cron job for pushing metrics to pushgateway does not exist"
   fi
else
  echo "cron daemon is not running"
   if [ `crontab -l |grep curl |grep filebeat |wc -l` -eq 1 ]; then
      echo "the cron job for push metrics to pushigateway is below"
      crontab -l |grep curl |grep filebeat
   else
      echo "However the cron job for pushing metrics to pushgateway does not exist"
   fi
fi

echo -e '\r'
} 2>&1 | tee -a /tmp/dashbase_collector_check.log 
