import unittest
from asterisk.asterisk import convert_dateformat, get_config
from asterisk.asterisk import get_pattern


class AsteriskTest(unittest.TestCase):
    def testBasic(self):
        self.assertEqual("", convert_dateformat(""))
        self.assertEqual("''''", convert_dateformat("'"))
        self.assertEqual("''''''", convert_dateformat("''"))
        self.assertEqual("''''''''", convert_dateformat("'''"))

    def testConvert(self):
        dashbase_pattern = convert_dateformat('%F %T')
        self.assertEqual("yyyy-MM-dd HH:mm:ss", dashbase_pattern)

    def testConvert1(self):
        dashbase_pattern = convert_dateformat('%F %T 123')
        self.assertEqual("yyyy-MM-dd HH:mm:ss '123'", dashbase_pattern)

    def testConvert2(self):
        dashbase_pattern = convert_dateformat("%F %T '123'")
        self.assertEqual("yyyy-MM-dd HH:mm:ss '''123'''", dashbase_pattern)

    def testConvert3(self):
        dashbase_pattern = convert_dateformat("%F %T '\"[")
        self.assertEqual("yyyy-MM-dd HH:mm:ss '''\"['", dashbase_pattern)

    def testConvert4(self):
        dashbase_pattern = convert_dateformat("%F %T.%3q '\"[")
        self.assertEqual("yyyy-MM-dd HH:mm:ss.SSS '''\"['", dashbase_pattern)

    def testConvert5(self):
        dashbase_pattern = convert_dateformat("%a, %d %b %y %T %z '\"[")
        self.assertEqual("EEE, dd MMM yy HH:mm:ss Z '''\"['", dashbase_pattern)

    def testConvert6(self):
        dashbase_pattern = convert_dateformat("%D %R '\"[")
        self.assertEqual("MM/dd/yy HH:mm '''\"['", dashbase_pattern)

    def testConvert7(self):
        dashbase_pattern = convert_dateformat("%c '\"[")
        self.assertEqual("EEE MMM d HH:mm:ss yyyy '''\"['", dashbase_pattern)

    def testGetPattern(self):
        conf_file = "./tests/logger.conf"
        config = get_config(conf_file)
        dashbase_pattern = get_pattern(config)
        self.assertEqual('\[%{GREEDYDATA:timestamp:datetime:yyyy-MM-dd HH:mm:ss}\] %{WORD:level:meta}\[%{INT:lwp:int}\] %{JAVAFILE:source:meta}: %{GREEDYDATA:message}',dashbase_pattern)
