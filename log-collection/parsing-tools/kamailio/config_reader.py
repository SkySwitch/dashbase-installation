import re
import logging


class ConfigReader:

    def __init__(self,conf_file, path_to_sample_logs):
        self.xLogs = []
        self.log_sample = ''
        self.log_sample_file_name = path_to_sample_logs
        self.kamailio_config = conf_file
        self.read_log_sample()
        self.read_xlog_from_kamailio_config()



    def read_log_sample(self):
        with open(self.log_sample_file_name) as fp:
            try:
                line = fp.readline()
                cnt = 1
                while line:
                    logging.info("Reading Line {}: {}".format(cnt, line.strip()))

                    # Store last line in sample log
                    if len(line) > 0:
                        self.log_sample = line.strip()
                    line = fp.readline()
                    cnt += 1
            except:
                logging.error("Failed to read sample log file.")
            finally:
                fp.close()
        return self

    def read_xlog_from_kamailio_config(self):
        with open(self.kamailio_config) as fp:
            try:
                line = fp.readline()
                cnt = 1
                while line:
                    # Store all of them
                    regex = r"xlog(.*);"
                    matches = re.finditer(regex, line, re.MULTILINE)
                    for matchNum, match in enumerate(matches, start=1):
                        logging.debug("Match {matchNum} was found at {start}-{end}: {match}".format(matchNum=matchNum,
                                                                                                    start=match.start(),
                                                                                                    end=match.end(),
                                                                                                    match=match.group()))
                        self.xLogs.append(match.group())
                    line = fp.readline()
                    cnt += 1
            except:
                logging.error("Failed to read xlog config file.")
            finally:
                fp.close()
        return self

