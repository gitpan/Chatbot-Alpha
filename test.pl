#!/usr/bin/perl -w

use lib "./lib";
use Data::Dumper;
use Chatbot::Alpha;

my $alpha = new Chatbot::Alpha (debug => 1);
print "Chatbot::Alpha version $Chatbot::Alpha::VERSION\n\n";

# Load test replies.
my $load = $alpha->loadFile ('./testreplies.txt');
die "Error: $load" unless $load == 1;

print "\n\n";

# Stream additional replies.
$alpha->stream ("+ what is alpha\n"
	. "- Alpha, aka Chatbot::Alpha, is a chatterbot brain created by AiChaos Inc.\n\n"
	. "+ who created alpha\n"
	. "- Chatbot::Alpha was created by Cerone Kirsle.");

print "\n\n\n\n";

$alpha->sortReplies;

# User ID (so the module can keep track of different talkers)
my $id = "foo";

print "Setting Variables Test\n"
	. "Botmaster? [1|0] or <0> ";
my $bm = <STDIN>;
print "Name? or <user> ";
my $name = <STDIN>;

$bm ||= 0;
$name ||= 'user';

chomp $bm;
chomp $name;
$name = lc($name);

$alpha->setVariable ("master",$bm);
$alpha->setVariable ("name",$name);

# Loop.
while (1) {
	print "  You> ";
	my $msg = <STDIN>;
	chomp $msg;

	exit(0) if $msg =~ /^exit$/i;

	# Get a reply.
	my $reply = $alpha->reply ($id,$msg);

	$reply =~ s/\\n/\n/g;

	print "Alpha> $reply\n\n";
}