#!/usr/bin/env perl
# Author: Jamie Davis <davisjam@vt.edu>
# Description: Drive regex through the various analyses.
#
# Dependencies:
#   - ECOSYSTEM_REGEXP_PROJECT_ROOT must be defined
#   - VULN_REGEX_DETECTOR_ROOT must be defined

use strict;
use warnings;

use JSON::PP; # I/O
use Carp;

my $LOG_FILE = "/tmp/analyze-regexp-$$.log";

# Check dependencies.
if (not defined $ENV{ECOSYSTEM_REGEXP_PROJECT_ROOT}) {
  die "Error, ECOSYSTEM_REGEXP_PROJECT_ROOT must be defined\n";
}

my $superLinearAnalysis = "$ENV{ECOSYSTEM_REGEXP_PROJECT_ROOT}/vuln-regex-detector/bin/check-regex.pl";
my $degreeOfVulnAnalysis = "$ENV{ECOSYSTEM_REGEXP_PROJECT_ROOT}/degree-of-vuln/estimate-blowup-curve.pl";
my $structuralAnalysis = "$ENV{ECOSYSTEM_REGEXP_PROJECT_ROOT}/structural-analysis/run-structural-analysis.pl";
my $semanticAnalysis = "$ENV{ECOSYSTEM_REGEXP_PROJECT_ROOT}/semantic-meaning/guess-patterns-language.pl";

for my $script ($superLinearAnalysis, $structuralAnalysis, $semanticAnalysis, $degreeOfVulnAnalysis) {
  if (not -x $script) {
    die "Error, script is not executable: $script\n";
  }
}

# Check args.
if (scalar(@ARGV) != 1) {
  die "Usage: $0 pattern.json\n";
}

my $patternFile = $ARGV[0];
if (not -f $patternFile) {
  die "Error, no such file: $patternFile\n";
}

my $i = 1;
open(my $FH, "<", "$patternFile") or die "Error, could not open $patternFile: $!\n";
while (my $line = <$FH>) {
  # Skip non-JSON things.
  next if ($line !~ m/^\s*{.*}\s*$/);

  &log("Processing pattern $i");
  $i++;
  my $pattern = decode_json($line);

  &log("Analyzing pattern /$pattern->{pattern}/");
  my $superLinearResult = &runSuperLinearAnalysis($pattern);
  my $degreeOfVulnResult = &runDegreeOfVulnAnalysis($pattern, $superLinearResult);
  my $structuralResult = &runStructuralAnalysis($pattern);
  my $semanticResult = &runSemanticAnalysis($pattern);

  &log("Emitting result");
  my $fullAnalysis = {
    "pattern" => $pattern,
    "superLinear" => $superLinearResult,
    "degreeOfVuln" => $degreeOfVulnResult,
    "structural" => $structuralResult,
    "semantic" => $semanticResult,
  };
  print STDOUT encode_json($fullAnalysis) . "\n";
}
close($FH);

exit 0;

#######################

sub runSuperLinearAnalysis {
  my ($pattern) = @_;

  my $query = {
    "useCache" => 0,
    "pattern" => $pattern->{pattern},
    "detectVuln_detectors" => ["weideman-RegexStaticAnalysis", "wustholz-RegexCheck", "rathnayake-rxxr2"],
    "detectVuln_timeLimit" => 60,
    "detectVuln_memoryLimit" => 1024,
    "validateVuln_language" => $pattern->{language},
  };
  my $queryFile = "/tmp/superLinearAnalysis-queryFile-$$.json";
  &writeToFile("file"=>$queryFile, "contents"=>encode_json($query));
  my $out = &chkcmd("$superLinearAnalysis $queryFile 2>>$LOG_FILE");
  unlink $queryFile;

  return decode_json($out);
}

sub runDegreeOfVulnAnalysis {
  my ($pattern, $superLinearResult) = @_;

  # If vulnerable, 

  return {};
}

sub runStructuralAnalysis {
  my ($pattern) = @_;

  my $query = {
    "pattern" => $pattern->{pattern},
  };
  my $queryFile = "/tmp/structuralAnalysis-queryFile-$$.json";
  &writeToFile("file"=>$queryFile, "contents"=>encode_json($query));
  my $out = &chkcmd("$structuralAnalysis $queryFile 2>>$LOG_FILE");
  unlink $queryFile;

  return decode_json($out);
}

sub runSemanticAnalysis {
  my ($pattern) = @_;

  my $query = {
    "pattern" => $pattern->{pattern},
  };
  my $queryFile = "/tmp/semanticAnalysis-queryFile-$$.json";
  &writeToFile("file"=>$queryFile, "contents"=>encode_json($query));
  my $out = &chkcmd("$semanticAnalysis $queryFile 2>>$LOG_FILE");
  unlink $queryFile;

  return decode_json($out);
}

#####################

sub chkcmd {
  my ($cmd) = @_;
  my ($rc, $out) = &cmd($cmd);
  if ($rc) {
    die "Error, cmd <$cmd> gave rc $rc:\n$out\n";
  }

  return $out;
}

# input: ($cmd)
# output: ($rc, $out)
sub cmd {
  my ($cmd) = @_;
  &log("CMD: $cmd");
  my $out = `$cmd`;
  return ($? >> 8, $out);
}

sub log {
  my ($msg) = @_;
  print STDERR "$msg\n";
}

# input: %args: keys: file
# output: $contents
sub readFile {
  my %args = @_;

	open(my $FH, '<', $args{file}) or confess "Error, could not read $args{file}: $!";
	my $contents = do { local $/; <$FH> }; # localizing $? wipes the line separator char, so <> gets it all at once.
	close $FH;

  return $contents;
}

# input: %args: keys: file contents
# output: $file
sub writeToFile {
  my %args = @_;

	open(my $fh, '>', $args{file});
	print $fh $args{contents};
	close $fh;

  return $args{file};
}

sub emitAndExit {
  my ($result) = @_;
  print STDOUT encode_json($result) . "\n";
  exit 0;
}
