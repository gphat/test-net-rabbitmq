use inc::Module::Install;

name     'Test-Net-RabbitMQ';
all_from 'lib/Test/Net/RabbitMQ.pm';
author   q{Cory G Watson <gphat@cpan.org>};
license  'perl';

build_requires 'Test::Exception';
build_requires 'Test::More';

requires 'Moose';

WriteAll;

