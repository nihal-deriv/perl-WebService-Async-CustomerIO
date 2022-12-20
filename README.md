# NAME

WebService::Async::CustomerIO - unofficial support for the Customer.io service

# SYNOPSIS

# DESCRIPTION

## new

Creates a new API client object

Usage: `new(%params) -> obj`

Parameters:

- `site_id`
- `api_key`
- `api_token`

## site\_id

## api\_key

## api\_token

## API endpoints:

There is 2 stable API for Customer.io, if you need to add a new method check
the [documentation for API](https://customer.io/docs/api/) which endpoint
you need to use:

- `Tracking API` - Behavioral Tracking API is used to identify and track
customer data with Customer.io.
- `Regular API` - Currently, this endpoint is used to fetch list of customers
given an email and for sending
[API triggered broadcasts](https://customer.io/docs/api-triggered-broadcast-setup).

## tracking\_request

Sending request to Tracking API end point.

Usage: `tracking_request($method, $uri, $data) -> future($data)`

## api\_request

Sending request to Regular API end point with optional limit type.

Usage: `api_request($method, $uri, $data, $limit_type) -> future($data)`

## new\_customer

Creating new customer object

Usage: `new_customer(%params) -> obj`

## new\_trigger

Creating new trigger object

Usage: `new_trigger(%params) -> obj`

## new\_customer

Creating new customer object

Usage: `new_customer(%params) -> obj`

## add\_to\_segment

Add people to a manual segment.

Usage: `add_to_segment($segment_id, @$customer_ids) -> Future()`

## remove\_from\_segment

remove people from a manual segment.

usage: c<< remove\_from\_segment($segment\_id, @$customer\_ids) -> future() >>

## get\_customers\_by\_email

Query Customer.io API for list of clients, who has requested email address.

usage: c<< get\_customers\_by\_email($email)->future(\[$customer\_obj1, ...\]) >>
