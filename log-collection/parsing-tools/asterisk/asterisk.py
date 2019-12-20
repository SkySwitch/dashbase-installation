#!/usr/bin/python
# -*- coding: utf-8 -*-
import os
import sys
import locale
import time
import datetime
import argparse
import ConfigParser as configparser

########################################################################################################################
# See source code in https://github.com/apache/tomcat/blob/master/java/org/apache/catalina/util/Strftime.java#L52-L105
'''
    Q/q
    The subsecond component of a UTC timestamp. The default is milliseconds, %3Q. Valid values are:
    %3Q = milliseconds, with values of 000-999
    %6Q = microseconds, with values of 000000-999999
    %9Q = nanoseconds, with values of 000000000-999999999
'''

PATTERNS = {
    "%a": "EEE",
    "%A": "EEEE",
    "%b": "MMM",
    "%B": "MMMM",
    "%c": "EEE MMM d HH:mm:ss yyyy",
    "%d": "dd",
    "%D": "MM/dd/yy",
    "%e": "dd",
    "%F": "yyyy-MM-dd",
    "%g": "yy",
    "%G": "yyyy",
    "%h": "MMM",
    "%H": "HH",
    "%I": "hh",
    "%j": "DDD",
    "%k": "HH",
    "%l": "hh",
    "%m": "MM",
    "%M": "mm",
    "%n": "\n",
    "%p": "a",
    "%P": "a",
    "%r": "hh:mm:ss a",
    "%R": "HH:mm",
    "%S": "ss",
    "%t": "\t",
    "%T": "HH:mm:ss",
    "%V": "ww",
    "%x": "MM/dd/yy",
    "%X": "HH:mm:ss",
    "%y": "yy",
    "%Y": "yyyy",
    "%z": "Z",
    "%Z": "z",
    "%3q": "SSS",
    "%6q": "SSSSSS",
    "%9q": "SSSSSSSSS",
    "%3Q": "SSS",
    "%6Q": "SSSSSS",
    "%9Q": "SSSSSSSSS",
    "%%": "%"
}


def quote(qstr, inside_quotes):

    return "'" + qstr + "'" if inside_quotes else qstr


def translate_command(buf, pattern, index, old_inside):

    first_char = pattern[index]
    new_inside = old_inside

    if first_char == 'O' or first_char == 'E':
        if index + 1 < len(pattern):
            new_inside, buf = translate_command(buf, pattern, index + 1, old_inside)
        else:
            buf += quote("%" + first_char, old_inside)
    else:
        if first_char == '3' and pattern[index+1] == 'q':
            command = PATTERNS.get("%" + first_char+pattern[index+1], None)
        else:
            command = PATTERNS.get("%" + first_char, None)
        if not command:
            print("ERROR: Found unsupported specifications: %{}".format(first_char))
            exit(1)
        else:
            if old_inside:
                buf += "'"
            buf += command
            new_inside = False
    return new_inside, buf


# TODO:
#   1. Fix ', ",( ,), [, ] in pattern
def convert_dateformat(pattern):

    inside = False
    mark = False
    modified_command = False
    buf = ""

    for index, char in enumerate(pattern):
        if char == 'q' and pattern[index-1] == '3':
            continue;

        if char == '%' and not mark:
            mark = True
        else:
            if mark:
                if modified_command:
                    # don't do anything--we just wanted to skip a char
                    modified_command = False
                    mark = False
                else:
                    inside, buf = translate_command(buf, pattern, index, inside)
                    if char == 'O' or char == 'E':
                        modified_command = True
                    else:
                        mark = False
            else:
                if not inside and char != ' ' and char != '.':
                    buf += "'"
                    inside = True

                buf += char if char != "'" else "''"

    if len(buf) > 0:
        if inside:
            buf += "'"
    return buf


########################################################################################################################


def get_pattern(config):
    ''' create filebeat parsing grok pattern based on the logging configuration
    '''
    use_callids = config.get('general', 'use_callids', 'yes') == 'yes'
    appendhostname = config.get('general', 'appendhostname', 'no') == 'yes'
    dateformat = config.get('general', 'dateformat', '')
    queue_log = config.get('general', 'queue_log', 'yes') == 'yes'

    pattern = ''
    if dateformat:
        pattern = '\[%{GREEDYDATA:timestamp:datetime:' + convert_dateformat(dateformat) + '}\] '
    else:
        pattern = '\[%{SYSLOGTIMESTAMP:timestamp:datetime:MMM ppd HH:mm:ss}\\] '

    pattern += '%{WORD:level:meta}\[%{INT:lwp:int}\]'
    if use_callids:
        pattern += '(\[%{DATA:callid:text}\])?'
    pattern += ' '

    pattern += '%{JAVAFILE:source:meta}: %{GREEDYDATA:message}'

    return pattern


def read_config_file(filename):
    ''' Reads main logger configuration file, finds all #included configuration files and
    put all content of these files into a string buffer
    '''

    buf = ''
    if not os.path.isfile(filename):
        print("ERROR: File {} is not found".format(filename, flush=True))
        return buf

    with open(filename, 'r') as f:
        while True:
            line = f.readline()
            if not line:
                return buf
            if not line.startswith("#include"):
                buf += line
            else:
                _, sfile = line.rsplit(None, 2)
                include_filename = os.path.join(os.path.dirname(filename), sfile)
                buf += read_config_file(include_filename)


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
  multiline.pattern: '^\['
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
            fp.write(path+document) 
            print("Created asterisk filebeat configuration file {} successfully".format(filebeat_config))
        except Exception, e:
            print("ERROR: Failed to output asterisk filebeat configuration file", e)


def get_config(conf_file):
    ''' Reads logging configuration files
        Returns ConfigParser object config '''
 
    buf = read_config_file(conf_file)
    try:
        # write buf into a file for ConfigParser to open
        aggregated_config = os.path.join(os.getcwd(), 'aggregated.conf')
        fout = open(aggregated_config, 'w')
        fout.write(buf) 
        fout.close()
        config = configparser.ConfigParser()
        config.read(aggregated_config)
        if 'general' not in config.sections():
            print("ERROR: Section 'general' is not found in the config files. "
                  "Not able to proceed with pattern configuration, exiting")
            exit(1)
        return config

    except configparser.ParsingError as e:
        print(error(e))
    finally:
        if os.path.exists(aggregated_config): 
            os.unlink(aggregated_config)


def main():

    parser = argparse.ArgumentParser(
        description='script to generate filebeat configuration file based on logging configuration file for asterisk server',
        usage='use "python %(prog)s --help" for more information',
        formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument('-c', '--conf_file', help='''file to read logging configuration from.
    Example: python asterisk.py -c /tmp/logging.conf
    If logging.conf includes other configuration files with #include,
    they also need to be accessible in the same folder''')

    parser.add_argument('-o', '--output_filebeat_file', help='''yaml file to write created filebeat configuration.
    Example: python asterisk.py -o /tmp/asterisk.yaml''')

    parser.add_argument('-p', '--path_to_logs', help='''path to the asterisk logs to collect from with filebeat.
    Example: python asterisk.py -p /var/log/asterisk/full*''')

    # TODO: Uncomment
    '''
     if locale.getdefaultlocale()[0] != 'en_US':
        print("This machine is not in the locale of 'en_US'. This may break the dashbase parsing because Asterisk "
              "will output log according to the current locale")
    '''
    args = parser.parse_args()
    conf_file = args.conf_file
    if not conf_file: 
        conf_file = raw_input("Enter asterisk logger.conf path:")

    path_to_logs = args.path_to_logs
    if not path_to_logs:
        path_to_logs = raw_input("Enter path to the asterisk logs to collect from [default: /var/log/asterisk/full*]:")
        if not path_to_logs:
            path_to_logs = '/var/log/asterisk/full*'

    filebeat_file = args.output_filebeat_file
    if not filebeat_file:
        tm = datetime.datetime.fromtimestamp(time.time()).strftime("%Y-%m-%d_%H:%M:%S")
        filebeat_file = os.path.join(os.getcwd(), 'asterisk-{}.yaml'.format(tm)) 
        
    print('\nReading logging configuration from: {}\nWriting filebeat configuration to: {}\nUsing path to logs: {}\n'
        .format(conf_file, filebeat_file, path_to_logs))
    config = get_config(conf_file)
    filebeat_pattern = get_pattern(config)
    print("Your pattern is: '{}'".format(filebeat_pattern))

    write_filebeat_config(filebeat_pattern, filebeat_file, path_to_logs)


if __name__ == '__main__':
    main()

