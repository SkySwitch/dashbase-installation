import argparse
import re
import os
import logging


class ConfigReader:

    def __init__(self):
        self.xLogs = []
        self.log_sample = ''
        self.parser = argparse.ArgumentParser(
            description='script to generate filebeat configuration file based on logging configuration file for kamailio server',
            usage='use "python %(prog)s --help" for more information',
            formatter_class=argparse.RawTextHelpFormatter)
        self.log_sample_file_name = self.read_log_sample_path()
        self.kamailio_config = self.read_kamailio_config_path()
        self.read_log_sample()
        self.read_xlog_from_kamailio_config()

    def read_kamailio_config_path(self):
        self.parser.add_argument('-c', '--conf_file', help='''file to read logging configuration from.
            Example: python kamailio.py -c /tmp/kamailio.cfg''')
        self.args = self.parser.parse_args()
        conf_file = self.args.conf_file
        if not conf_file:
            conf_file = raw_input("Enter kamailio config file (kamailio.cfg) path:")
        return conf_file


    def read_log_sample_path(self):
        self.parser.add_argument('-l', '--path_to_sample_logs', help='''path to the kamailio sample logs to find date format, level, format etc.
            Example: python kamilio.py -l /var/log/kamilio/message*''')
        self.args = self.parser.parse_args()
        path_to_sample_logs = self.args.path_to_sample_logs
        if not path_to_sample_logs:
            path_to_sample_logs = raw_input(
                "Enter path to the kamailio sample logs to collect from [default: /var/log/kamailio/full*]:")
            if not path_to_sample_logs:
                path_to_logs = '../tests/log'
        return path_to_sample_logs

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

