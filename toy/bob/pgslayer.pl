#!/usr/bin/env perl

use strict; use warnings;

use AnyEvent;
use AnyEvent::HTTPD;
use AE::DBI;

use Encode;
use JSON;
use URI;

sub config {
  my ($name) = @_;
  $name or die "$0 <configfile>";
  open(my $fh, '<:utf8', $name) or die $!;
  local $/;
  my $json = <$fh>;
  close($fh);
  return decode_json($json);
}

sub run {
  my $config = config(@_);

  my $httpd = AnyEvent::HTTPD->new (
    host => $config->{httpd_host},
    port => $config->{httpd_port},
  );

  $httpd->reg_cb(
    '' => sub {
      my ($httpd,$req) = @_;

      my $error = sub {
        $req->respond([map { encode_utf8($_) } @_]);
        $httpd->stop_request;
        return;
      };

      my $url = URI->new($req->url);
      my $path = $url->path;

      my ($db_name) = ($path =~ m{^/(\w+)$}) or return $error->(404);
      my $conf = $config->{db}->{$db_name} or return $error->(404);

      my $json = eval { decode_json($req->content) };
      !$@ && ref($json) eq 'HASH' or return $error->(418,$@);

      my $sql = $json->{sql} or return $error->(501);
      my $params = $json->{params} || [];

      my $dbh = AE::DBI->new (
        $conf->{location},
        $conf->{username},
        $conf->{password},
      );

      # $_dbh{$dbh} = $dbh;

      $dbh->on_error( sub { undef $dbh; return $error->(500,$@) } );
      $dbh->timeout(12);

      $dbh->exec($sql,@$params,sub {
        my ($dbh2,$rows,$rv) = @_;

        undef $dbh;

        my $response = {};
        $response->{status} = $rv   if $rv;
        $response->{error}  = $@    if $@;
        $response->{rows}   = $rows if $rows;

        $req->respond([200,'OK',{ 'Content-Type' => 'application/json' }, encode_json($response)]);
      });
    },
  );

  $httpd->run;
}

run(@ARGV);