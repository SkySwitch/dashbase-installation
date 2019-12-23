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

    parser.add_argument('-o', '--output_filebeat_file', help='''yaml file to write created filebeat configuration.
        Example: python kamailio.py -o /tmp/kamailio.yaml''')
    args = parser.parse_args()

    filebeat_file = args.output_filebeat_file
    if not filebeat_file:
        tm = datetime.datetime.fromtimestamp(time.time()).strftime("%Y-%m-%d_%H:%M:%S")
        filebeat_file = os.path.join(os.getcwd(), 'kamailio-{}.yaml'.format(tm))

    logging.basicConfig(level=logging.DEBUG)
    configReader = ConfigReader()
    builder = LogToPatternBuilder(configReader.log_sample)
    count = 0
    for xLog in configReader.xLogs:
        decoder = XlogFormatDecoder(xLog)
        pattern = builder.pattern
        if len(decoder.log_config) > 0:
            pattern += decoder.log_config
            logging.debug(pattern)
            count = count + 1
            buildConfig(pattern, "patternType" + str(count))
    writeConfig(filebeat_file)
    logging.debug('Done! I am going home. (Good)Bye!')


if __name__ == '__main__':
    main()
