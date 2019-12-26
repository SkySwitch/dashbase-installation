import argparse
import datetime
import time

from config_reader import ConfigReader
from log_pattern_builder import LogToPatternBuilder
from xlog_format_decoder import XlogFormatDecoder
import os
import yaml
import logging

dict_list = []

SPECIAL_CHAR = ['*', '[', ']']


def write_filebeat_config(filebeat_config, path_to_logs):
    ''' Writes filebeat configuration for kamailio using pattern and path_to_logs
    '''

    with open(filebeat_config, "a+") as fp:
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
          parsers: {}
            """

            path += '"{}"'.format(path_to_logs)
            fp.write(path + '\n')
            cur_yaml = yaml.load(document, Loader=yaml.FullLoader)
            for dict in dict_list:
                cur_yaml['fields']['_message_parser']['parsers']['grok']['parsers'].update(dict)
            # TODO: yaml dumps adds new line char in patterns. Fix this.
            yaml.safe_dump(cur_yaml, fp)
            print("Created kamailio filebeat configuration file {} successfully".format(filebeat_config))
        except Exception, e:
            print("ERROR: Failed to output kamailio filebeat configuration file", e)


def build_config(pattern, pattern_type):
    dict_file = {"pattern": pattern, "type": 'grok'}
    dict_list.append({pattern_type: dict_file});


def escape(pattern):
    for char in SPECIAL_CHAR:
        pattern = pattern.replace(char, '\\' + char)
    return pattern


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
            escaped_pattern = escape(pattern)
            build_config(escaped_pattern, "kamailio_pattern_type_" + str(count))
            logging.info(escaped_pattern)

    write_filebeat_config(filebeat_file, path_to_logs)

    logging.debug('Done! I am going home. (Good)Bye!')


if __name__ == '__main__':
    main()
