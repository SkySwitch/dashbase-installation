import re
from collections import OrderedDict

class LogToPatternBuilder:

    REGEX_GROK_PATTERN = {
        "[a-zA-Z]{3} \d{2} \d{2}:\d{2}:\d{2}": "%{DATA:timestamp:datetime:MMM ppd HH:mm:ss} ",
        "[a-zA-Z]{3} \d{2} \d{2}:\d{2}:\d{2}.\d{1,3}": "%{DATA:timestamp:datetime:MMM ppd HH:mm:ss.SSS} ",
        "[a-zA-Z]{3} \d{2} \d{2}:\d{2}:\d{2}.\d{4,6}": "%{DATA:timestamp:datetime:MMM ppd HH:mm:ss.SSSSSS} "
    }
    SORTED_REGEX_GROK_PATTERN  = sorted(REGEX_GROK_PATTERN, key=REGEX_GROK_PATTERN.get, reverse=False)

    def __init__(self, logSample):
        self.log_sample = logSample
        self.pattern = self.find_pattern_from_log()

    def find_pattern_from_log(self):
        self.pattern = ''
        for regex in self.SORTED_REGEX_GROK_PATTERN:
            matches = re.findall(regex, self.log_sample)
            date = "".join(matches)
            if len(date) > 0:
                self.pattern += self.REGEX_GROK_PATTERN[regex]
                break

        #TODO: test and chnage it to \b(?:[0-9A-Za-z][0-9A-Za-z-]{0,62})(?:\.(?:[0-9A-Za-z][0-9A-Za-z-]{0,62}))*(\.?|\b)
        matches = re.findall("[a-zA-Z1-9]{1,3}-[a-zA-Z1-9]{1,3}-[a-zA-Z1-9]{1,3}-[a-zA-Z1-9]{1,3}-[a-zA-Z1-9]{1,3}", self.log_sample)
        ip = "".join(matches)
        if len(ip) > 0:
            self.pattern += "(?:%{SYSLOGFACILITY} )?%{SYSLOGHOST:logsource:meta} %{SYSLOGPROG}: (%{DATA:pid})? "

        # level - The level that will be used in LOG function. It can be:
        # L_ALERT - log level -5
        # L_BUG - log level -4
        # L_CRIT - log level -3
        # L_ERR - log level -1
        # L_WARN - log level 0
        # L_NOTICE - log level 1
        # L_INFO - log level 2
        # L_DBG - log level 3
        log_level_list = {"ALERT","BUG","CRIT","ERR","WARN","NOTICE","INFO","DBG"}

        for log_level in log_level_list:
            matches = re.findall(log_level,
                                 self.log_sample)
            if len(matches) > 0:
                self.pattern += "%{LOGLEVEL:level:meta}: "
                break

        matches = re.findall("[<][a-zA-Z]{1,10}[>]:", self.log_sample)
        script = "".join(matches)
        if len(script) > 0:
            self.pattern += "%{DATA:script}:? "

        return self.pattern


