# Filebeat Installation for Windows

## Download and install Filebeat
```

   1. Login to Windows Server 2012 as an Administrator 

   2. Download Filebeat OSS 6.8.5 from https://www.elastic.co/downloads/past-releases/filebeat-oss-6-8-5 

   3. Unzip filebeat-oss-6.8.5-windows-x86_64.zip. Unzipping will create filebeat-oss-6.8.5-windows-x86_64 folder.  

   4. Open Powershell with Administrator priviledge and move filebeat-oss-6.8.5-windows-x86_64 folder to “c:\program files\”:

      mv c:\Users\Administrator\Downloads\filebeat-oss-6.8.5-windows-x86_64\filebeat-6.8.5-windows-x86_64\ "c:\Program files\filebeat"

   5. In the Powershell, go to filebeat folder and run install script:
      cd "c:\Program files\filebeat" 
      powershell.exe -ExecutionPolicy UnRestricted -File .\install-service-filebeat.ps1

```

## Create filebeat conifguration

```
   1. Get filebeat.yml example from dashbase installation repository.

      git clone https://github.com/dashbase/dashbase-installation.git

      Path to the filebeat.yml in the repository:
      dashbase-installation/log-collection/windows/filebeat.yml

   2. Open filebeat.yml in the text editor and provide appropriate values for:

      LOG_PATH - full path to the log file(s) to send to Dashbase. Can use wildcard.
      Example: 
      c:\logs\pjsip.log

      PARSING_PATTERN - grok parsing pattern. Contact Dashbase support if not sure what it is.

      DASHBASE_URL - Dashbase table URL
      Example:
      table-logs.dashbase.io

   3. Copy updated filebeat.yml to “c:\Program files\filebeat“

```
## Start Filebeat and check that it's sending log records to Dashbase
```

   1. Start filebeat service in the Powershell:
      Start-Service filebeat

   2. Check filebeat log to make sure that it was able to connect to DASHBASE_URL and send data.
      Filebeat log:
      c:\ProgramData\filebeat\logs\filebeat

      Should see lines similar to:
      
      2020-02-04T18:23:35.753-0800	INFO	elasticsearch/client.go:164	Elasticsearch url: https://table-logs.staging.dashbase.io:443
      2020-02-04T18:23:35.753-0800	DEBUG	[publish]	pipeline/consumer.go:137	start pipeline event consumer
      2020-02-04T18:23:35.754-0800	INFO	[publisher]	pipeline/module.go:110	Beat name: WIN-U6PO2Q5G8L3
      2020-02-04T18:23:35.757-0800	INFO	instance/beat.go:402	filebeat start running.
      ...
      2020-02-04T18:23:35.770-0800	INFO	log/harvester.go:255	Harvester started for file: c:\logs\pjsip.log
      2020-02-04T18:23:35.773-0800	DEBUG	[publish]	pipeline/processor.go:309	Publish event: {
        "@timestamp": "2020-02-05T02:23:35.772Z",
        "@metadata": {
          "beat": "filebeat",
          "type": "doc",
          "version": "6.8.5"
        },
        "message":
      ...

    3. Use Dashbase Web UI to confirm that log data are searchable.
```
