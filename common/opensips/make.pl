#!/usr/bin/env perl
# clean.pl -- merge OpenSIPS configuration fragments
# Copyright (C) 2009  Stephane Alnet
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
use strict; use warnings;
use File::Spec;
use CCNQ::Logger;
use CCNQ::Util;
use JSON;

=h1 clean_cfg

  Rename route statements and prune unavailable ones.
  Process macros.

=cut

sub macros_cfg {
  my ($t,$params) = @_;

  my %macros;

  # Macro pre-processing
  $t =~ s{ \b macro           \s+ (\w+) \b
           (.*?)
           \b end \s+ macro \s+ \1 \b }
         { $macros{$1} = $2, '' }gsxe;
  # Macros may contain params, so substitute them first.
  $t =~ s{ \$ \{ (\w+) \} }
         { defined $macros{$1} ? $macros{$1} : qq(\${$1}) }gsxe;

  # Evaluate parameters after macro substitution
  $t =~ s{ \b define          \s+ (\w+) \b }
         { $params->{$1} = 1, '' }gsxe;
  $t =~ s{ \b undef           \s+ (\w+) \b }
         { $params->{$1} = 0, '' }gsxe;

  $t =~ s{ \b if \s+ not \s+ (\w+) \b
           (.*?)
           \b end \s+ if \s+ not \s+ \1 \b }
         { exists($params->{$1}) && $params->{$1} ? '' : $2 }gsxe;
  $t =~ s{ \b if \s+ (\w+) \s+ is \s+ not \s+ (\w+) \b
           (.*?)
           \b end \s+ if \s+ \1 \s+ is \s+ not \s+ \2 \b }
         { exists($params->{$1}) && $params->{$1} eq $2 ? '' : $3 }gsxe;
  $t =~ s{ \b if \s+ (\w+) \s+ is \s+ (\w+) \b
           (.*?)
           \b end \s+ if \s+ \1 \s+ is \s+ \2 \b }
         { exists($params->{$1}) && $params->{$1} eq $2 ? $3 : '' }gsxe;
  $t =~ s{ \b if \s+ (\w+) \b
           (.*?)
           \b end \s+ if \s+ \1 \b }
         { exists($params->{$1}) && $params->{$1} ? $2 : '' }gsxe;

  # Substitute parameters
  $t =~ s{ \$ \{ (\w+) \} }
         { defined $params->{$1} ? $params->{$1} : (error("Undefined $1"),'') }gsxe;

  return $t;
}

sub clean_cfg {
  my ($t,$params) = @_;

  $t = macros_cfg($t,$params);

  my @available = ($t =~ m{ \b route \[ ([^\]]+) \] }gsx);
  my %available = map { $_ => 0 } @available;
  $t =~ s{ \b route \( ([^\)]+) \) }{
    exists($available{$1})
      ? ($available{$1}++, "route($1)")
      : (warning("Removing unknown route($1)"),"")
  }gsxe;

  my @unused = grep { !$available{$_} } sort keys %available;
  error( q(Unused routes (replace with macros): ).join(', ',@unused) ) if @unused;

  my @used = grep { $available{$_} } sort keys %available;

  my $route = 0;
  my %route = map { $_ => ++$route } sort @used;

  warning("Found $route routes");

  $t =~ s{ \b route \( ([^\)]+) \) \s* ([;\#\)]) }{ "route($route{$1}) $2" }gsxe;
  $t =~ s{ \b route \[ ([^\]]+) \] \s* ([\{\#]) }{ "route[$route{$1}] $2" }gsxe;

  $t .= "\n".join('', map { "# route($route{$_}) => route($_)\n" } sort keys %route);

  return $t;
}


=h1 compile_cfg

    Build OpenSIPS configuration from fragments.

=cut

sub compile_cfg {
  my ($base_dir,$params) = @_;

  my @recipe = @{$params->{recipe}};

  my $result = <<EOH;
#
# Automatically generated
# $params->{comment}
#
EOH

  for my $extension qw(variables modules cfg) {
    for my $building_block (@recipe) {
      my $file = File::Spec->catfile($base_dir,'fragments',"${building_block}.${extension}");
      if( -f $file ) {
        $result .= "\n## ---  Start ${file}  --- ##\n\n";
        $result .= CCNQ::Util::content_of($file);
        $result .= "\n## ---  End ${file}  --- ##\n\n";
      }
    }
  }
  return clean_cfg($result,$params);
}

=h1 compile_sql

  Build SQL configuration from fragments.

=cut

sub help_on_sql {
  my ($params) = @_;

  return unless $params->{db_name};

  # Print out some info on how to use the SQL file.
  my $runtime_opensips_sql = $params->{runtime_opensips_sql};
  my $db_name     = $params->{db_name};
  my $db_login    = $params->{db_login};
  my $db_password = $params->{db_password};
  info(<<TXT);
Please run the following commands:
mysql <<SQL
  CREATE DATABASE ${db_name};
  CONNECT ${db_name};
  CREATE USER ${db_login} IDENTIFIED BY '${db_password}';
  GRANT ALL ON ${db_name}.* TO ${db_login};
SQL

mysql ${db_name} < ${runtime_opensips_sql}

TXT

}

sub compile_sql {
  my ($base_dir,$params) = @_;

  my @recipe = @{$params->{recipe}};

  my $result = '';
  my $extension = 'sql';
  for my $building_block (@recipe) {
    my $file = File::Spec->catfile($base_dir,'src',"${building_block}.${extension}");
    if( -f $file ) {
      $result .= CCNQ::Util::content_of($file);
    }
  }
  return macros_cfg($result,$params);
}

=pod

  configure_opensips
    Subtitute configuration variables in a complete OpenSIPS configuration file
    (such as one generated by compile_cfg).

=cut

sub configure_opensips {
  my ($params) = @_;

  # Handle special parameters specially
  if(exists($params->{avp_aliases})) {
    $params->{avp_aliases}= join(';',map { "$_=I:$params->{avp_aliases}->{$_}" } (sort keys %{$params->{avp_aliases}}));
  }
  if(exists($params->{cdr_extra})) {
    $params->{cdr_extra} = join(';',@{$params->{cdr_extra}});
  }
  if(exists($params->{radius_extra})) {
    $params->{radius_extra} = join(';',@{$params->{radius_extra}});
  }

  my $cfg_text = compile_cfg($params->{opensips_base_lib},$params);
  my $sql_text = compile_sql($params->{opensips_base_lib},$params);

  CCNQ::Util::print_to($params->{runtime_opensips_cfg},$cfg_text);
  CCNQ::Util::print_to($params->{runtime_opensips_sql},$sql_text);

  help_on_sql($params);
}

configure_opensips(decode_json(CCNQ::Util::content_of($ARGV[0])));

1;