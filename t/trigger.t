use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;

use Future;

use WebService::Async::CustomerIO;
use WebService::Async::CustomerIO::Trigger;


subtest 'Creating API client' => sub {
    my @tests = (
        [{campaign_id => 1}, qr/^Missing required argument: api_client/],
        [{api_clien => 1}, qr/^Missing required argument: campaign_id/],
    );

    for my $test_case (@tests) {
        throws_ok {
            WebService::Async::CustomerIO::Trigger->new(%{$test_case->[0]})
        } $test_case->[1], "Got Expected error";
    }

    ok(WebService::Async::CustomerIO::Trigger->new( campaign_id => 1, api_client => 1), 'Trigger created');
};

subtest 'Getters methods' => sub {
    my $time = time;
    my $trigger = WebService::Async::CustomerIO::Trigger->new(
        campaign_id => 'some_id',
        api_client => 'some_api_client',
        id => 'trigger_id',
    );

    is $trigger->api, 'some_api_client', 'Get api client';
    is $trigger->id, 'trigger_id', 'Get id';
    is $trigger->campaign_id, 'some_id', 'Get campaign_id';
};

subtest 'Api Methods tests' => sub {
    my $time = time;
    subtest 'activate' => sub {
        my $api = WebService::Async::CustomerIO->new(
            site_id => 'some_site_id',
            api_key => 'some_api_key',
        );

        $api = Test::MockObject::Extends->new($api);
        $api->mock(api_request => sub {Future->done({id => 1})});

        my $trigger = WebService::Async::CustomerIO::Trigger->new(
            campaign_id => 'some_id',
            api_client => $api,
        );

        is $trigger->id, undef, 'id is empty before request';
        my $response = $trigger->activate->get;
        is_deeply $response, {id => 1}, 'Response is correct';
        is $trigger->id, 1, 'id is updated';
    };

    subtest 'find' => sub {
        my $api = WebService::Async::CustomerIO->new(
            site_id => 'some_site_id',
            api_key => 'some_api_key',
        );

        $api = Test::MockObject::Extends->new($api);
        $api->mock(api_request => sub {Future->done({campaign_id => 1, id =>2})});

        my $trigger = WebService::Async::CustomerIO::Trigger->find($api, 1, 1)->get;

        is $trigger->id, 2, 'Trigger id is correct';
        is $trigger->campaign_id, 1, 'campaign id is correct';
    };

    subtest 'get_errors' => sub {
        my $api = WebService::Async::CustomerIO->new(
            site_id => 'some_site_id',
            api_key => 'some_api_key',
        );

        $api = Test::MockObject::Extends->new($api);
        $api->mock(api_request => sub {
            my %h;
            @h{qw(method uri data)} = @_[1..3];
            Future->done(\%h);
         });

        my $trigger = WebService::Async::CustomerIO::Trigger->new(
            campaign_id => 'some_id',
            api_client => $api,
            id => 1,
        );

        my $response = $trigger->get_errors->get;

        is $response->{method}, 'GET', 'Method is correct';
        is $response->{uri}, 'campaigns/some_id/triggers/1/errors', 'URI is correct';
        is_deeply $response->{data}, {}, 'Data is correct';
    };
};



done_testing();
