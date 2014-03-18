use strict;
use warnings;

use Test::More;
use Net::Ping;
use Data::Dumper;

BEGIN {
    unless (use_ok( 'Selenium::Remote::Driver'))
    {
        BAIL_OUT ("Couldn't load Driver");
        exit;
    }

    if (defined $ENV{'WD_MOCKING_RECORD'} && ($ENV{'WD_MOCKING_RECORD'}==1)) {
        use t::lib::MockSeleniumWebDriver;
        my $p = Net::Ping->new("tcp", 2);
        $p->port_number(4444);
        unless ($p->ping('localhost')) {
            plan skip_all => "Selenium server is not running on localhost:4444";
            exit;
        }
        warn "\n\nRecording...\n\n";
    }
}

my $record = (defined $ENV{'WD_MOCKING_RECORD'} && ($ENV{'WD_MOCKING_RECORD'}==1))?1:0;
my $os  = $^O;
if ($os =~ m/(aix|freebsd|openbsd|sunos|solaris)/) {
    $os = 'linux';
}
my $mock_file = "01-driver-mock-$os.json";
if (!$record && !(-e "t/mock-recordings/$mock_file")) {
    plan skip_all => "Mocking of tests is not been enabled for this platform";
}
t::lib::MockSeleniumWebDriver::register($record,"t/mock-recordings/$mock_file");

my $driver = new Selenium::Remote::Driver(browser_name => 'firefox');
my $website = 'http://localhost:63636';
my $ret;

CHECK_DRIVER: {
    ok(defined $driver, 'Object loaded fine...');
    ok($driver->isa('Selenium::Remote::Driver'), '...and of right type');
    ok(defined $driver->{'session_id'}, 'Established session on remote server');
    $ret = $driver->get_capabilities;
    is($ret->{'browserName'}, 'firefox', 'Right capabilities');
    my $status = $driver->status;
    ok($status->{build}->{version},"Got status build.version");
    ok($status->{build}->{revision},"Got status build.revision");
    ok($status->{build}->{time},"Got status build.time");
}

IME: {
  SKIP: {
        eval {$driver->available_engines;};
        if ($@) {
            skip "ime not available on this system",3;
        }
    };
}

LOAD_PAGE: {
    $driver->get("$website/index.html");
    pass('Loaded home page');
    $ret = $driver->get_title();
    is($ret, 'Hello WebDriver', 'Got the title');
    $ret = $driver->get_current_url();
    ok($ret =~ m/$website/i, 'Got proper URL');
}

WINDOW: {
    $ret = $driver->get_current_window_handle();
    ok($ret =~ m/^{.*}$/, 'Proper window handle received');
    $ret = $driver->get_window_handles();
    is(ref $ret, 'ARRAY', 'Received all window handles');
    $ret = $driver->set_window_position(100,100);
    is($ret, 1, 'Set the window position to 100, 100');
    $ret = $driver->get_window_position();
    is ($ret->{'x'}, 100, 'Got the right X Co-ordinate');
    is ($ret->{'y'}, 100, 'Got the right Y Co-ordinate');
    $ret = $driver->set_window_size(640, 480);
    is($ret, 1, 'Set the window size to 640x480');
    $ret = $driver->get_window_size();
    is ($ret->{'height'}, 640, 'Got the right height');
    is ($ret->{'width'}, 480, 'Got the right width');
    $ret = $driver->get_page_source();
    ok($ret =~ m/^<html/i, 'Received page source');
    eval {$driver->set_implicit_wait_timeout(20001);};
    ok(!$@,"Set implicit wait timeout");
    eval {$driver->set_implicit_wait_timeout(0);};
    ok(!$@,"Reset implicit wait timeout");
    $ret = $driver->get("$website/frameset.html");
    $ret = $driver->switch_to_frame('second');
}

COOKIES: {
    $driver->get("$website/cookies.html");
    $ret = $driver->get_all_cookies();
    is(@{$ret}, 2, 'Got 2 cookies');
    $ret = $driver->delete_all_cookies();
    pass('Deleting cookies...');
    $ret = $driver->get_all_cookies();
    is(@{$ret}, 0, 'Deleted all cookies.');
    $ret = $driver->add_cookie('foo', 'bar', '/', 'localhost', 0);
    pass('Adding cookie foo...');
    $ret = $driver->get_all_cookies();
    is(@{$ret}, 1, 'foo cookie added.');
    is($ret->[0]{'secure'}, 0, 'foo cookie insecure.');
    $ret = $driver->delete_cookie_named('foo');
    pass('Deleting cookie foo...');
    $ret = $driver->get_all_cookies();
    is(@{$ret}, 0, 'foo cookie deleted.');
    $ret = $driver->delete_all_cookies();
}

MOVE: {
    $driver->get("$website/index.html");
    $driver->get("$website/formPage.html");
    $ret = $driver->go_back();
    pass('Clicked Back...');
    $ret = $driver->get_title();
    is($ret, 'Hello WebDriver', 'Got the right title');
    $ret = $driver->go_forward();
    pass('Clicked Forward...');
    $ret = $driver->get_title();
    is($ret, 'We Leave From Here', 'Got the right title');
    $ret = $driver->refresh();
    pass('Clicked Refresh...');
    $ret = $driver->get_title();
    is($ret, 'We Leave From Here', 'Got the right title');
}

FIND: {
    my $elem = $driver->find_element("//input[\@id='checky']");
    ok($elem->isa('Selenium::Remote::WebElement'), 'Got WebElement via Xpath');
    $elem = $driver->find_element('checky', 'id');
    ok($elem->isa('Selenium::Remote::WebElement'), 'Got WebElement via Id');
    $elem = $driver->find_element('checky', 'name');
    ok($elem->isa('Selenium::Remote::WebElement'), 'Got WebElement via Name');

    $elem = $driver->find_element('multi', 'id');
    $elem = $driver->find_child_element($elem, "option");
    ok($elem->isa('Selenium::Remote::WebElement'), 'Got child WebElement...');
    $ret = $elem->get_value();
    is($ret, 'Eggs', '...right child WebElement');
    $ret = $driver->find_child_elements($elem, "//option[\@selected='selected']");
    is(@{$ret}, 4, 'Got 4 WebElements');
    my $expected_err = "An element could not be located on the page using the "
    . "given search parameters: "
    . "element_that_doesnt_exist,id"
    # the following needs to always be right before the eval
    . " at " . __FILE__ . " line " . (__LINE__+1);
    eval { $driver->find_element("element_that_doesnt_exist","id"); };
    chomp $@;
    is($@,$expected_err.".","find_element croaks properly");
}

EXECUTE: {
    my $script = q{
          var arg1 = arguments[0];
          var elem = window.document.getElementById(arg1);
          return elem;
        };
    my $elem = $driver->execute_script($script,'checky');
    ok($elem->isa('Selenium::Remote::WebElement'), 'Executed script');
    is($elem->get_attribute('id'),'checky','Execute found proper element');
    $script = q{
          var links = window.document.links
          var length = links.length
          var results = new Array(length)
          while(length--) results[length] = links[length];
          return results;
        };
    $elem = $driver->execute_script($script);
    ok($elem, 'Got something back from execute_script');
    isa_ok($elem, 'ARRAY', 'What we got back is an ARRAY ref');
    ok(scalar(@$elem), 'There are elements in our array ref');
    foreach my $element (@$elem) {
        isa_ok($element, 'Selenium::Remote::WebElement', 'Element was converted to a WebElement object');
    }
    $script = q{
          var arg1 = arguments[0];
          var callback = arguments[arguments.length-1];
          var elem = window.document.getElementById(arg1);
          callback(elem);
        };
    $elem = $driver->execute_async_script($script,'multi');
    ok($elem->isa('Selenium::Remote::WebElement'),'Executed async script');
    is($elem->get_attribute('id'),'multi','Async found proper element');
}

ALERT: {
    $driver->get("$website/alerts.html");
    $driver->find_element("alert",'id')->click;
    is($driver->get_alert_text,'cheese','alert text match');
    eval {$driver->dismiss_alert;};
    ok(!$@,"dismissed alert");
    $driver->find_element("prompt",'id')->click;
    is($driver->get_alert_text,'Enter your name','prompt text match');
    $driver->send_keys_to_prompt("Larry Wall");
    eval {$driver->accept_alert;};
    ok(!$@,"accepted prompt");
    is($driver->get_alert_text,'Larry Wall','keys sent to prompt');
    $driver->dismiss_alert;
    $driver->find_element("confirm",'id')->click;
    is($driver->get_alert_text,"Are you sure?",'confirm text match');
    eval {$driver->dismiss_alert;};
    ok(!$@,"dismissed confirm");
    is($driver->get_alert_text,'false',"dismissed confirmed correct");
    $driver->accept_alert;
    $driver->find_element("confirm",'id')->click;
    eval {$driver->accept_alert;};
    ok(!$@,"accepted confirm");
    is($driver->get_alert_text,'true',"accept confirm correct");
    $driver->accept_alert;
}

PAUSE: {
    my $starttime=time();
    $driver->pause();
    my $endtime=time();
    ok($starttime <= $endtime-1,"starttime <= endtime+1"); # Slept at least 1 second
    ok($starttime >= $endtime-2,"starttime >= endtime-2"); # Slept at most 2 seconds
}

AUTO_CLOSE: {
    my $stayOpen = Selenium::Remote::Driver->new(
        browser_name => 'firefox',
        auto_close => 0
    );

    $stayOpen->DESTROY();
    ok(defined $stayOpen->{'session_id'}, 'auto close in init hash is respected');
    $stayOpen->auto_close(1);
    $stayOpen->DESTROY();
    ok(!defined $stayOpen->{'session_id'}, 'true for auto close is still respected');

    $driver->auto_close(0);
    $driver->DESTROY();
    ok(defined $driver->{'session_id'}, 'changing autoclose on the fly keeps the session open');
    $driver->auto_close(1);
}

QUIT: {
    $ret = $driver->quit();
    ok((not defined $driver->{'session_id'}), 'Killed the remote session');
}

done_testing;
