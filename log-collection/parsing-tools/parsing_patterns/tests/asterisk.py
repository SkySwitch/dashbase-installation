import unittest

from ..asterisk.asterisk import convert_dateformat


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
