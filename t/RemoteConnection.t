#! /usr/bin/perl

use strict;
use warnings;
use Data::Printer;
use Selenium::Remote::RemoteConnection;
use Test::LWP::UserAgent;
use Test::More;

my $tua = Test::LWP::UserAgent->new();

$tua->map_response(qr\/wd/hub/status\, HTTP::Response->new(
    '200', 'OK', ['Content-Type' => 'application/json'],
    q/{"status":0,"sessionId":null,"value":{"os":{"arch":"x86_64","name":"Mac OS X","version":"10.9.2"},"java":{"version":"1.6.0_65"},"build":{"revision":"ff23eac","time":"2013-12-16 16:11:15","version":"2.39.0"}},"state":"success","class":"org.openqa.selenium.remote.Response","hCode":797952442}/
   ));

LOCALHOST: {
    $tua->map_response(qr\localhost.*wd/hub/session\, HTTP::Response->new(
    '200', 'OK', ['Content-Type' => 'application/json'],
    q/{"status":0,"sessionId":"26fbcd66-3ed3-4fa9-b62c-9ee3dc4feb70","value":{"platform":"MAC","javascriptEnabled":true,"cssSelectorsEnabled":true,"browserName":"htmlunit","webdriver.remote.sessionid":"26fbcd66-3ed3-4fa9-b62c-9ee3dc4feb70","version":""},"state":null,"class":"org.openqa.selenium.remote.Response","hCode":2073285362}/
   ));

    my $conn = Selenium::Remote::RemoteConnection->new(
        remote_server_addr => "localhost",
        port => 4444,
        ua => $tua
       );

    my $res = $conn->request("POST", "session", { desiredCapabilities => { browserName => 'chrome' }});

    ok(exists($res->{sessionId}), "we made a localhost session!");
}

REMOTE: {
    $tua->map_response(qr\saucelabs.*wd/hub/session\, HTTP::Response->new(
    '200', 'OK', ['Content-Type' => 'application/json'],
    q/{"status": 0, "sessionId": "d4a64df904c64cc2b1f9851feb365422", "value": {"rotatable": false, "browserConnectionEnabled": false, "acceptSslCerts": false, "cssSelectorsEnabled": true, "javascriptEnabled": true, "databaseEnabled": false, "chrome.chromedriverVersion": "26.0.1383.0", "locationContextEnabled": false, "takesScreenshot": true, "platform": "linux", "browserName": "chrome", "version": "28.0.1500.95", "hasMetadata": true, "nativeEvents": true, "applicationCacheEnabled": false, "webStorageEnabled": true, "handlesAlerts": true}}/
    ));

    my $conn = Selenium::Remote::RemoteConnection->new(
        remote_server_addr => "username:authentication\@ondemand.saucelabs.com",
        port => 80,
        ua => $tua
       );

    my $res = $conn->request("POST", "session", { desiredCapabilities => { browserName => 'chrome' }});
    ok(exists($res->{sessionId}), "we made a saucelabs session!");
}

done_testing;
