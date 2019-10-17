use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::MockObject::Extends;

use IO::Async::Loop;

use WebService::Async::CustomerIO::RateLimiter;


subtest 'Creating limiter' => sub {
    my @tests = (
        [{interval => 1}, qr/^Missing requeread argument: limit/],
        [{limit => 1}, qr/^Missing requeread argument: interval/],
        [{limit => 1, interval => 0}, qr/^Invalid value for interval/],
        [{limit => 1, interval => -1}, qr/^Invalid value for interval/],
        [{limit => 0, interval =>1}, qr/^Invalid value for limit/],
        [{limit => -1, interval => 1}, qr/^Invalid value for limit/],
    );

    for my $test_case (@tests) {
        throws_ok {
            WebService::Async::CustomerIO::RateLimiter->new(%{$test_case->[0]})
        } $test_case->[1], "Got Expected error";
    }

    ok(WebService::Async::CustomerIO::RateLimiter->new(limit => 1, interval => 1), 'RateLimiter created');
};


subtest 'Get current queue' => sub {
    my @tests = (
        [{limit => 1, counter => 2}, { expected_pos =>0 }],
        [{limit => 1, counter => 3}, { expected_pos =>1 }],
        [{limit => 2, counter => 3}, { expected_pos =>0 }],
        [{limit => 2, counter => 4}, { expected_pos =>0 }],
        [{limit => 2, counter => 5}, { expected_pos =>1 }],
        [{limit => 2, counter => 6}, { expected_pos =>1 }],
        [{limit => 3, counter => 4}, { expected_pos =>0 }],
        [{limit => 3, counter => 5}, { expected_pos =>0 }],
        [{limit => 3, counter => 6}, { expected_pos =>0 }],
        [{limit => 3, counter => 7}, { expected_pos =>1 }],
        [{limit => 3, counter => 8}, { expected_pos =>1 }],
        [{limit => 3, counter => 9}, { expected_pos =>1 }],
    );

    for my $test_case (@tests) {
        my ($data, $result) = @{$test_case};
        my $limiter = WebService::Async::CustomerIO::RateLimiter->new(
            limit => $data->{limit}, 
            interval => 1
        );

        $limiter->{counter} = $data->{counter};

        $limiter->_current_queue;

        is $#{$limiter->{queue}}, $result->{expected_pos}, 'Got Expected result';
    }
};

subtest 'Acquiring limiter' => sub  {
    my $limiter = WebService::Async::CustomerIO::RateLimiter->new(limit => 1, interval => 1);
    $limiter = Test::MockObject::Extends->new($limiter);
    $limiter->set_true('_start_timer');
    ok $limiter->acquire->is_done,'Returns done future until limit is reached';
    ok !$limiter->acquire->is_done,'Returns undone future when limit is reached';
    is scalar(@{$limiter->{queue}}), 1, 'Queue contains single element';
};

subtest 'Reset timer' => sub {
    my $loop = IO::Async::Loop->new;
    my $limiter = WebService::Async::CustomerIO::RateLimiter->new(limit => 1, interval => 1);

    $loop->add($limiter);
    ok $limiter->acquire->is_done, 'Returns done future';
    is $limiter->{counter}, 1, 'Counter is increased';
    my $future = $limiter->acquire;
    ok !$future->is_done, 'Returns undone future';
    is $limiter->{counter}, 2, 'Counter is increased';

    $loop->delay_future( after => 1 )->get;
    is $limiter->{counter}, 1, 'Counter is decreesed';
    ok $future->is_done, 'Delayed future is resolved';
};

done_testing();

