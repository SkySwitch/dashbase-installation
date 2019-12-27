import re
import logging

class XlogFormatDecoder:

    def __init__(self, log):
        self.log_config = log
        try:
            x = re.findall("xlog(.*);", self.log_config)
            self.log_config = "".join(x).split(',')[1][1:-4].strip()
            self.get_pattern()
            logging.debug("XLog: " + log)
            logging.debug("XLog Pattern: " + self.log_config)
        except:
            logging.error("Error Parsing xlog facility and level")
            self.log_config = ''

    def get_pattern(self):
        regex = r"[$][a-zA-Z1-9]{1,256}([(][a-z]{1,256}[)])?"

        matches = re.finditer(regex, self.log_config, re.MULTILINE)

        for matchNum, match in enumerate(matches, start=1):
            logging.debug ("Match {matchNum} was found at {start}-{end}: {match}".format(matchNum=matchNum, start=match.start(),
                                                                                 end=match.end(), match=match.group()))
            self.log_config = self.log_config.replace(match.group(), "%{{DATA:{var}}}".format(
                var=match.group().replace('$', '').replace("(", "-").replace(")", '')))

        removal = "DATA"
        reverse_removal = removal[::-1]
        replacement = "GREEDYDATA"
        reverse_replacement = replacement[::-1]

        self.log_config = self.log_config[::-1].replace(reverse_removal, reverse_replacement, 1)[::-1]
        logging.info(self.log_config)
        return self

