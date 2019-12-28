from unittest import TestCase

from kamailio.log_pattern_builder import LogToPatternBuilder


class TestLogToPatternBuilder(TestCase):

    def test_find_pattern_from_log1(self):
        builder = LogToPatternBuilder("Nov 20 11:45:07 ip-192-168-12-214 kamailio: 4(27089) INFO: <script>: [DEFAULT_ROUTE] *New request INVITE* rU=1008/tU=1008/fU=1007/rd=192.168.12.214/si=172.17.0.10/sp=39531")
        self.assertEqual("%{DATA:timestamp:datetime:MMM ppd HH:mm:ss} (?:%{SYSLOGFACILITY} )?%{SYSLOGHOST:logsource:meta} %{SYSLOGPROG}: (%{DATA:pid})? %{LOGLEVEL:level:meta}: %{DATA:script}:? ",builder.pattern)


    def test_find_pattern_from_log2(self):
        builder = LogToPatternBuilder("Nov 20 11:45:07.234 ip-192-168-12-214 kamailio: 4(27089) INFO: <script>: [DEFAULT_ROUTE] *New request INVITE* rU=1008/tU=1008/fU=1007/rd=192.168.12.214/si=172.17.0.10/sp=39531")
        self.assertEqual("%{DATA:timestamp:datetime:MMM ppd HH:mm:ss.SSS} (?:%{SYSLOGFACILITY} )?%{SYSLOGHOST:logsource:meta} %{SYSLOGPROG}: (%{DATA:pid})? %{LOGLEVEL:level:meta}: %{DATA:script}:? ",builder.pattern)

    def test_find_pattern_from_log3(self):
        builder = LogToPatternBuilder("Nov 20 11:45:07.234245 ip-192-168-12-214 kamailio: 4(27089) INFO: <script>: [DEFAULT_ROUTE] *New request INVITE* rU=1008/tU=1008/fU=1007/rd=192.168.12.214/si=172.17.0.10/sp=39531")
        self.assertEqual("%{DATA:timestamp:datetime:MMM ppd HH:mm:ss.SSSSSS} (?:%{SYSLOGFACILITY} )?%{SYSLOGHOST:logsource:meta} %{SYSLOGPROG}: (%{DATA:pid})? %{LOGLEVEL:level:meta}: %{DATA:script}:? ",builder.pattern)

