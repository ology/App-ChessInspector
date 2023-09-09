#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

use Chess::Inspector;

# TODO convert to a mojo test!

route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 200, 'response status is 200 for /';
