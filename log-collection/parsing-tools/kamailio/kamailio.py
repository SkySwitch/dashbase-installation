import argparse
import sys
import os
import datetime
import time

from config_reader import ConfigReader
from log_pattern_builder import LogToPatternBuilder
from xlog_format_decoder import XlogFormatDecoder
import os
import yaml
import logging

dict_list = []


def write_filebeat_config(pattern, filebeat_config, path_to_logs):
    ''' Writes filebeat configuration for asterisk using pattern and path_to_logs
    '''

    with open(filebeat_config, "w") as fp:
        try:
            path = """
- paths:
    - """
            document = """
  type: log
  multiline.pattern: '^.'
  multiline.negate: true
  multiline.match: after
  close_inactive: 90s
  harvester_limit: 1000
  scan_frequency: 1s
  symlinks: true
  clean_removed: true
  fields:
    _message_parser:
      type: multi
      applyAll: 'true'
      parsers:
        sip:
          type: sip
        grok:
          type: multi
          parsers:
            freepbx:
              type: grok
              pattern: "\\[%{TIMESTAMP_ISO8601:timestamp:datetime:yyyy-MM-dd HH:mm:ss}\\] %{WORD:level:meta}\\[%{INT:lwp:int}\\](\\[%{DATA:callid:text}\\])? %{JAVAFILE:source:meta}: %{GREEDYDATA:message}"
            asterisk:
              type: grok
              pattern: """

            path += '"{}"'.format(path_to_logs)
            document += '"{}"'.format(pattern)
            fp.write(path + document)
            print("Created asterisk filebeat configuration file {} successfully".format(filebeat_config))
        except Exception, e:
            print("ERROR: Failed to output asterisk filebeat configuration file", e)


def writeConfig(filebeat_file):
    with open(filebeat_file, "w") as fp:
        try:
            fp.truncate(0)
            fp.write("\n")
            yaml.dump(dict_list, fp)
        except:
            logging.error("Failed to dump YAML config.")
        finally:
            fp.close()


def buildConfig(pattern, patternType):
    dict_file = {"pattern": pattern, "type": 'grok', "multiline.pattern": '^.', "multiline.negate": True,
                 "multiline.match": 'after'}
    dict_list.append({patternType: dict_file});


def main():
    parser = argparse.ArgumentParser(
        description='script to generate filebeat configuration file based on logging configuration file for kamailio server',
        usage='use "python %(prog)s --help" for more information',
        formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument('-c', '--conf_file', help='''file to read logging configuration from.
               Example: python kamailio.py -c /tmp/kamailio.cfg''')

    parser.add_argument('-o', '--output_filebeat_file', help='''yaml file to write created filebeat configuration.
        Example: python kamailio.py -o /tmp/kamailio.yaml''')

    parser.add_argument('-l', '--path_to_sample_logs', help='''path to the kamailio sample logs to find date format, level, format etc.
                Example: python kamailio.py -l /var/log/kamilio/message*''')

    parser.add_argument('-p', '--path_to_logs', help='''path to the kamailio logs to collect from with filebeat.
        Example: python kamailio.py -p /var/log/kamailio/message*''')

    args = parser.parse_args()
    print (args)

    filebeat_file = args.output_filebeat_file
    if not filebeat_file:
        tm = datetime.datetime.fromtimestamp(time.time()).strftime("%Y-%m-%d_%H:%M:%S.%f")[:-3]
        filebeat_file = os.path.join(os.getcwd(), 'kamailio-{}.yaml'.format(tm))

    conf_file = args.conf_file
    if not conf_file:
        conf_file = raw_input("Enter kamailio config file (kamailio.cfg) path:")

    path_to_sample_logs = args.path_to_sample_logs
    if not path_to_sample_logs:
        path_to_sample_logs = raw_input(
            "Enter path to the kamailio sample logs to collect from [default: /var/log/kamailio/full*]:")
        if not path_to_sample_logs:
            path_to_logs = '../tests/log'

    path_to_logs = args.path_to_logs
    if not path_to_logs:
        path_to_logs = raw_input(
            "Enter path to the kamailio logs to collect from [default: /var/log/kamailio/message*]:")
        if not path_to_logs:
            path_to_logs = '/var/log/kamailio/message*'

    logging.basicConfig(level=logging.DEBUG)
    configReader = ConfigReader(conf_file, path_to_sample_logs)
    builder = LogToPatternBuilder(configReader.log_sample)
    count = 0
    for xLog in configReader.xLogs:
        decoder = XlogFormatDecoder(xLog)
        pattern = builder.pattern
        if len(decoder.log_config) > 0:
            pattern += decoder.log_config
            logging.debug(pattern)
            count = count + 1
            time.sleep(1)
            #buildConfig(pattern, "patternType" + str(count))
            tm = datetime.datetime.fromtimestamp(time.time()).strftime("%Y-%m-%d_%H:%M:%S.%f")[:-3]
            filebeat_file = os.path.join(os.getcwd(), 'kamailio-{}.yaml'.format(tm))
            write_filebeat_config(pattern, filebeat_file, path_to_logs)

    #writeConfig(filebeat_file)
    logging.debug('Done! I am going home. (Good)Bye!')


if __name__ == '__main__':
    main()
