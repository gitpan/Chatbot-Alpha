#!/usr/bin/perl -w

use lib "./lib";
use Chatbot::Alpha;

my $alpha = new Chatbot::Alpha (debug => 0);
print "Chatbot::Alpha version $Chatbot::Alpha::VERSION\n\n";

# Load test replies.
my $load = $alpha->load_file ('./testreplies.txt');
die "Error: $load" unless $load == 1;

# Test the search feature.
print "Testing search...\n"
	. "\tFor: one\n";
my @one = $alpha->search ("one");
	print "\t\t" . join ("\n\t\t", @one);
print "\n";
print "\tFor: sorry\n";
my @two = $alpha->search ("sorry");
	print "\t\t" . join ("\n\t\t", @two);

print "\n\n";

# Stream additional replies.
$alpha->stream ("+ what is alpha\n"
	. "- Alpha, aka Chatbot::Alpha, is a chatterbot brain created by AiChaos Inc.\n\n"
	. "+ who created alpha\n"
	. "- Chatbot::Alpha was created by Cerone Kirsle.");

# User ID (so the module can keep track of different talkers)
my $id = "foo";

# Loop.
while (1) {
	print "  You> ";
	my $msg = <STDIN>;
	chomp $msg;

	exit(0) if $msg =~ /^exit$/i;

	# An example, setting a variable (see the "am i your master" reply in testreplies.txt)
	# Try setting this to 0 and see how Alpha replies to that. =)
	my $master = 1;

	# Set the "master" variable.
	$alpha->set_variable ("master",$master);

	# Get a reply.
	my $reply = $alpha->reply ($id,$msg);

	# Unset the "master" variable.
	$alpha->remove_variable ("master");

	$reply =~ s/\\n/\n/g;

	print "Alpha> $reply\n\n";
}