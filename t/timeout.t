use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/tlib";
use TestTimeout;

use PerlIO::via::Timeout;

use Errno qw(ETIMEDOUT);

subtest 'test with no delays and no timeouts', sub {
TestTimeout->test( connection_delay => 0,
                   read_delay => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $response = $client->getline;
                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       $response = $client->getline;
                       is $response, "SOK2\n", "got proper response 2";
                   },
                 );
};

subtest 'test with read timeout', sub {
TestTimeout->test( connection_delay => 0,
                   read_timeout => 0.2,
                   read_delay => 3,
                   write_timeout => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $response = $client->getline;
                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       ok ! PerlIO::via::Timeout->_fh2prop($client)->{_invalid}, "socket is valid";
                       $response = $client->getline;
                       is $response, undef, "we've hit timeout";
                       is 0+$!, ETIMEDOUT, "and error is timeout";
                       ok(PerlIO::via::Timeout->_fh2prop($client)->{_invalid}, "socket is not valid anymore");
                   },
                 );
};

subtest 'test with sysread timeout', sub {
TestTimeout->test( connection_delay => 0,
                   read_timeout => 0.2,
                   read_delay => 3,
                   write_timeout => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       sysread $client, my $response, 4;

                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       $response = undef;
                       ok ! PerlIO::via::Timeout->_fh2prop($client)->{_invalid}, "socket is valid";
                       sysread $client, $response, 5;
                       is $response, undef, "we've hit timeout";
                       is 0+$!, ETIMEDOUT, "and error is timeout";
                       ok(PerlIO::via::Timeout->_fh2prop($client)->{_invalid}, "socket is not valid anymore");
                   },
                 );
};

done_testing;

