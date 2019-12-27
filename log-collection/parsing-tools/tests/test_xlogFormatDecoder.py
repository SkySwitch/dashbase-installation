from unittest import TestCase

from kamailio.xlog_format_decoder import XlogFormatDecoder


class TestXlogFormatDecoder(TestCase):

    def test_get_pattern1(self):
        log = "xlog(\"L_INFO\",\"[$cfg(route)] *New request $rm* rU=$rU/tU=$tU/fU=$fU/rd=$rd/si=$si/sp=$sp \\n\");"
        decoder = XlogFormatDecoder(log)
        self.assertEqual("[%{DATA:cfg-route}] *New request %{DATA:rm}* rU=%{DATA:rU}/tU=%{DATA:tU}/fU=%{DATA:fU}/rd=%{DATA:rd}/si=%{DATA:si}/sp=%{GREEDYDATA:sp}",decoder.log_config)

    def test_get_pattern2(self):
        log = "xlog(\"L_ALERT\",\"ALERT: pike blocking $rm from $fu (IP:$si:$sp)\\n\");"
        decoder = XlogFormatDecoder(log)
        self.assertEqual("ALERT: pike blocking %{DATA:rm} from %{DATA:fu} (IP:%{DATA:si}:%{GREEDYDATA:sp})",decoder.log_config)
