package Chatbot::Alpha;

our $VERSION = '1.32';

# For debugging...
use strict;
use warnings;

sub new {
	my $proto = shift;

	my $class = ref($proto) || $proto;

	my $self = {
		debug   => 0,
		version => $VERSION,
		default => "I'm afraid I don't know how to reply to that!",
		@_,
	};

	bless ($self,$class);

	return $self;
}

sub version {
	my $self = shift;

	return $self->{version};
}

sub debug {
	my ($self,$msg) = @_;

	# Only show if debug mode is on.
	if ($self->{debug} == 1) {
		print STDOUT "Alpha::Debug // $msg\n";
	}

	return 1;
}

sub load_folder {
	my ($self,$dir) = (shift,shift);
	my $type = shift || undef;

	# Open the folder.
	opendir (DIR, $dir) or return 0;
	foreach my $file (sort(grep(!/^\./, readdir(DIR)))) {
		if (defined $type) {
			if ($file !~ /\.$type$/i) {
				next;
			}
		}

		my $load = $self->load_file ("$dir/$file");
		return $load unless $load == 1;
	}
	closedir (DIR);

	return 1;
}

sub load_file {
	my ($self,$file) = @_;

	$self->debug ("load_file called for file: $file");

	# Open the file.
	open (FILE, "$file") or return 0;
	my @data = <FILE>;
	close (FILE);
	chomp @data;

	# (Re)-define temporary variables.
	my $topic = 'random';
	my $inReply = 0;
	my $trigger = '';
	my $counter = 0;
	my $holder = 0;
	my $num = 0;

	# Go through the file.
	foreach my $line (@data) {
		$num++;
		$self->debug ("Line $num: $line");
		next if length $line == 0;
		next if $line =~ /^\//;
		$line =~ s/^\s//g;
		$line =~ s/^\t//g;

		# Get the command off.
		my ($command,$data) = split(//, $line, 2);

		# Go through commands...
		if ($command eq '>') {
			$self->debug ("> Command - Label Begin!");
			$data =~ s/^\s//g;
			my ($type,$text) = split(/\s+/, $data, 2);
			if ($type eq 'topic') {
				$self->debug ("Topic set to $data");
				$topic = $text;
			}
		}
		elsif ($command eq '<') {
			$self->debug ("< Command - Label Ender!");
			$data =~ s/^\s//g;
			if ($data eq 'topic' || $data eq '/topic') {
				$self->debug ("Topic reset");
				$topic = 'random';
			}
		}
		elsif ($command eq '+') {
			$self->debug ("+ Command - Reply Trigger!");
			if ($inReply == 1) {
				# New reply.
				$inReply = 0;
				$trigger = '';
				$counter = 0;
				$holder = 0;
			}

			# Reply trigger.
			$inReply = 1;

			$data =~ s/^\s//g;
			$data =~ s/([^A-Za-z0-9 ])/\\$1/ig;
			$data =~ s/\\\*/\(\.\*\?\)/i;
			$trigger = $data;
			$self->debug ("Trigger: $trigger");

			# Set the trigger's topic.
			$self->{_replies}->{$topic}->{$trigger}->{topic} = $topic;
		}
		elsif ($command eq '-') {
			$self->debug ("- Command - Reply Response!");
			if ($inReply != 1) {
				# Error.
				$self->debug ("Syntax Error at $file line $num");
				return -2;
			}

			# Reply response.
			$counter++;
			$data =~ s/^\s//g;

			$self->{_replies}->{$topic}->{$trigger}->{$counter} = $data;
			$self->debug ("Reply #$counter : $data");
		}
		elsif ($command eq '@') {
			# A redirect.
			$self->debug ("\@ Command - A Redirect!");
			if ($inReply != 1) {
				# Error.
				$self->debug ("Syntax Error at $file line $num");
				return -2;
			}
			$data =~ s/^\s//g;
			$self->{_replies}->{$topic}->{$trigger}->{redirect} = $data;
		}
		elsif ($command eq '*') {
			# A conditional.
			$self->debug ("* Command - A Conditional!");
			if ($inReply != 1) {
				# Error.
				$self->debug ("Syntax Error at $file line $num");
				return -2;
			}
			# Get the conditional's data.
			$data =~ s/^\s//g;
			$self->debug ("Counter: $counter");
			$self->{_replies}->{$topic}->{$trigger}->{conditions}->{$counter} = $data;
		}
		elsif ($command eq '&') {
			# A conversation holder.
			$self->debug ("\& Command - A Conversation Holder!");
			if ($inReply != 1) {
				# Error.
				$self->debug ("Syntax Error at $file line $num");
				return -2;
			}

			# Save this.
			$data =~ s/^\s//g;
			$self->debug ("Holder: $holder");
			$self->{_replies}->{$topic}->{$trigger}->{convo}->{$holder} = $data;
			$holder++;
		}
		elsif ($command eq '#') {
			# A system command.
			$self->debug ("\# Command - A System Command!");
			if ($inReply != 1) {
				# Error.
				$self->debug ("Syntax Error at $file line $num");
				return -2;
			}

			# Save this.
			$data =~ s/^\s//g;
			$self->debug ("System Command: $data");
			$self->{_replies}->{$topic}->{$trigger}->{system}->{codes} .= $data;
		}
	}

	return 1;
}

sub default_reply {
	my ($self,$reply) = @_;

	return 0 if length $reply == 0;

	# Save the reply.
	$self->{default} = $reply;
}

sub sort_replies {
	my $self = shift;

	# Reset loop.
	$self->{loops} = 0;

	# Fail if replies hadn't been loaded.
	return 0 unless exists $self->{_replies};

	# Delete the replies array (if it exists).
	if (exists $self->{_array}) {
		delete $self->{_array};
	}

	$self->debug ("Sorting the replies...");

	# Count replies.
	my $count = 0;

	# Go through each reply.
	foreach my $topic (keys %{$self->{_replies}}) {
		my @trigNorm = ();
		my @trigWild = ();
		foreach my $key (keys %{$self->{_replies}->{$topic}}) {
			$self->debug ("Sorting key $key");
			$count++;
			# If it's a wildcard...
			if ($key =~ /\*/) {
				# Save to wildcard array.
				$self->debug ("Key $key is a wildcard!");
				push (@trigWild, $key);
			}
			else {
				# Save to normal array.
				$self->debug ("Key $key is normal!");
				push (@trigNorm, $key);
			}
		}
		# Order the array.
		$self->{_array}->{$topic} = [
			@trigNorm,
			@trigWild,
		];
	}

	# Save the count.
	$self->{replycount} = $count;

	# Return true.
	return 1;
}

sub set_variable {
	my ($self,$var,$value) = @_;
	return 0 unless defined $var;
	return 0 unless defined $value;

	$self->{vars}->{$var} = $value;
	return 1;
}

sub remove_variable {
	my ($self,$var) = @_;
	return 0 unless defined $var;

	delete $self->{vars}->{$var};
	return 1;
}

sub clear_variables {
	my $self = shift;

	delete $self->{vars};
	return 1;
}

sub reply {
	my ($self,$id,$msg) = @_;

	# Sort replies if it hasn't already been done.
	if (!exists $self->{_array}) {
		$self->sort_replies;
	}

	# Too many loops?
	if ($self->{loops} >= 15) {
		$self->{loops} = 0;
		return "ERR: Deep Recursion (15+ loops in reply set)";
	}

	my %star;
	my $reply;

	# Topics?
	$self->{users}->{$id}->{topic} ||= 'random';

	$self->{users}->{$id}->{last} = '0' unless exists $self->{users}->{$id}->{last};

	$self->debug ("User Topic: $self->{users}->{$id}->{topic}");

	$self->debug ("Message: $msg");

	# Make sure some replies are loaded.
	if (!exists $self->{_replies}) {
		return "ERROR: No replies have been loaded!";
	}

	# Go through each reply.
	foreach my $topic (keys %{$self->{_array}}) {
		$self->debug ("On Topic: $topic");
		next unless $topic eq $self->{users}->{$id}->{topic};

		foreach my $in (@{$self->{_array}->{$topic}}) {
			$self->debug ("On Reply Trigger: $in");

			# Conversations?
			my $found_convo = 0;
			$self->debug ("Checking for conversation holders...");
			if (exists $self->{_replies}->{$topic}->{$in}->{convo}) {
				$self->debug ("This reply has a convo holder!");
				# See if this was our conversation.
				my $h = 0;
				for ($h = 0; exists $self->{_replies}->{$topic}->{$in}->{convo}->{$h}; $h++) {
					last if $found_convo == 1;
					$self->debug ("On Holder #$h");

					my $next = $self->{_replies}->{$topic}->{$in}->{convo}->{$h};

					$self->debug ("Last Msg: $self->{users}->{$id}->{last}");

					# See if this was for their last message.
					if ($self->{users}->{$id}->{last} =~ /^$in$/i) {
						if (!exists $self->{_replies}->{$topic}->{$in}->{convo}->{$self->{users}->{$id}->{hold}}) {
							delete $self->{users}->{$id}->{hold};
							$self->{users}->{$id}->{last} = $msg;
							last;
						}

						# Give the reply.
						$reply = $self->{_replies}->{$topic}->{$in}->{convo}->{$self->{users}->{$id}->{hold}};
						$self->{users}->{$id}->{hold}++;
						$star{msg} = $msg;
						$msg = $in;
						$found_convo = 1;
					}
				}
			}
			last if defined $reply;

			if ($msg =~ /^$in$/i) {
				$self->debug ("Reply Matched!");
				$star{1} = $1; $star{2} = $2; $star{3} = $3; $star{4} = $4; $star{5} = $5;
				$star{6} = $6; $star{7} = $7; $star{8} = $8; $star{9} = $9;

				# A redirect?
				$self->debug ("Checking for a redirection...");
				if (exists $self->{_replies}->{$topic}->{$in}->{redirect}) {
					$self->debug ("Redirection found! Getting new reply for $self->{_replies}->{$topic}->{$in}->{redirect}...");
					my $redirect = $self->{_replies}->{$topic}->{$in}->{redirect};

					# Filter in wildcards.
					for (my $s = 0; $s <= 9; $s++) {
						$redirect =~ s/<star$s>/$star{$s}/ig;
					}

					$self->{loops}++;
					$reply = $self->reply ($id,$redirect);
					return $reply;
				}

				# Conditionals?
				$self->debug ("Checking for conditionals...");
				if (exists $self->{_replies}->{$topic}->{$in}->{conditions}) {
					$self->debug ("This response DOES have conditionals!");
					# Go through each one.
					my $c = 0;
					for ($c = 0; exists $self->{_replies}->{$topic}->{$in}->{conditions}->{$c}; $c++) {
						$self->debug ("On Condition #$c");
						last if defined $reply;

						my $conditional = $self->{_replies}->{$topic}->{$in}->{conditions}->{$c};
						my ($condition,$happens) = split(/::/, $conditional, 2);
						$self->debug ("Condition: $condition");
						my @con = split(/ /, $condition, 4);
						$self->debug ("\@con = " . join (",", @con));
						$con[0] = lc($con[0]);
						if ($con[0] eq "if") {
							$self->debug ("A well-formed conditional.");
							# A good conditional.
							# ... see if the variable was defined.
							if (exists $self->{vars}->{$con[1]}) {
								$self->debug ("Variable asked for exists!");
								# Check values.
								if ($self->{vars}->{$con[1]} eq $con[3]) {
									$self->debug ("Values match!");
									# True. This is the reply.
									$reply = $happens;
									$self->debug ("Reply = $reply");
								}
							}
						}
					}
				}

				last if defined $reply;

				# A reply?
				return "ERROR: No reply set for \"$msg\"!" unless exists $self->{_replies}->{$topic}->{$in}->{1};

				my @replies;
				foreach my $key (keys %{$self->{_replies}->{$topic}->{$in}}) {
					next if $key =~ /[^0-9]/;
					push (@replies,$self->{_replies}->{$topic}->{$in}->{$key});
				}

				$reply = 'INFLOOP';
				while ($reply =~ /^(INFLOOP|HASH|SCALAR|ARRAY)/i) {
					$self->{loops}++;
					$reply = $replies [ int(rand(scalar(@replies))) ];
					if ($self->{loops} >= 20) {
						$reply = "ERR: Infinite Loop!";
					}
				}

				$self->debug ("Checking system commands...");
				# Execute system commands?
				if (exists $self->{_replies}->{$topic}->{$in}->{system}->{codes}) {
					$self->debug ("Found System: $self->{_replies}->{$topic}->{$in}->{system}->{codes}");
					my $eval = eval ($self->{_replies}->{$topic}->{$in}->{system}->{codes}) || $@;
					$self->debug ("Eval Result: $eval");
				}
			}
		}
	}

	# A reply?
	if (defined $reply) {
		# Filter in stars...
		my $i;
		for ($i = 1; $i <= 9; $i++) {
			$reply =~ s/<star$i>/$star{$i}/ig;
		}
		$reply =~ s/<msg>/$star{msg}/ig if exists $star{msg};
	}
	else {
		if ($self->{default} =~ /\|/) {
			my @default = split(/\|/, $self->{default});
			$reply = $default [ int(rand(scalar(@default))) ];
		}
		else {
			$reply = $self->{default};
		}
	}

	# A topic setter?
	if ($reply =~ /\{topic=(.*?)\}/i) {
		my $to = $1;
		if ($to eq 'random') {
			$self->{users}->{$id}->{topic} = '';
		}
		else {
			$self->{users}->{$id}->{topic} = $to;
		}
		$reply =~ s/\{topic=(.*?)\}//g;
	}

	# Save this message.
	$self->debug ("Saving this as last msg...");
	$self->{users}->{$id}->{last} = $msg;
	$self->{users}->{$id}->{hold} ||= 0;

	# Reset the loop timer.
	$self->{loops} = 0;

	# There SHOULD be a reply now.
	# So, return it.
	return $reply;
}

__END__

=head1 NAME

AiChaos, Inc.'s AlphaBot Reply System.

=head1 DESCRIPTION

Alpha is a simplistic yet very powerful response language.

=head1 SYNOPSIS

  use Alpha;
  my $alpha = new Chatbot::Alpha (debug => 1);

  $alpha->load_folder ('./replies');
  $alpha->load_file ('./more_replies.txt');

  # Set and remove variables.
  $alpha->set_variable ("master", "1");
  $alpha->remove_variable ("master");
  $alpha->set_variable ("var", "value");
  $alpha->clear_variables;

  # Go get a reply.
  my $user = "foo";
  my $message = "Hello Alpha";
  my $reply = $alpha->reply ($user,$message);

=head1 METHODS

=head2 new

Creates a new AlphaBot instance. If you want to have more than one
instance of Alpha (i.e. multiple bots), you need to create a new
instance for each one.

This can also take the flag DEBUG, if you are a developer.

  my $alpha = new Chatbot::Alpha (debug => 1);

=head2 version

Returns the version of the module, useful if you want to require
a specific version.

  my $version = $alpha->version;

=head2 debug

Prints a debug message... it shouldn't be called by itself, the module
will call it when a debug message needs to be printed.

  $alpha->debug ($message);

=head2 load_folder

Loads a whole folder of reply files. By default it will load every file it finds,
but if the folder contains files of other types it may cause errors... in this
case, a parameter of FILE_TYPE may be sent, so that it will only open that type
of file. It's always best to send the FILE_TYPE in anyway.

  $alpha->load_folder ("./replies", "txt");

Will return 0 if the folder couldn't be accessed, or -1 if the folder was empty
(or no files of the specified type were found), or -2 if there was a fatal error
with one of the files. Having debug mode turned on will reveal the problem.

=head2 load_file

Loads a single file. This is also called by the load_folder method for each file
in that folder. Returns the same values as load_folder (0 = file not found,
-2 = file had errors)

  $alpha->load_file ("./reply.txt");

=head2 default_reply

Sets the reply that Alpha will return if no better reply can be found. This can include
pipes for random responses.

  $alpha->default_reply ("Hmm...|I don't know.|Let's change the subject.");

=head2 sort_replies

Sorts the replies (normal triggers first, wildcards second). Call this subroutine after
loading all the reply files -- this subroutine will be called by the module itself when
it attempts to get a first reply, also.

  $alpha->sort_replies;

=head2 set_variable

Sets a global variable inside the brain.

  $alpha->set_variable ("var", "value");

=head2 remove_variable

Removes a global variable from the brain.

  $alpha->remove_variable ("var");

=head2 clear_variables

Clears all set variables added through set_variable

  $alpha->clear_variables;

=head2 reply

Gets a reply. Prerequisite is that replies have to be loaded, of course. Reply files
are loaded through the load_folder or load_file methods.

  my $reply = $alpha->reply ("Hello Alpha");

=head1 Alpha Language Tutorial

The Alpha reply language is a simple line-by-line command-driven language. The comment
indicator is a "//", as it is in JavaScript and C++. Each line has two components: the
first character, the command char., and the rest of the line, the command arguments.
The command characters are as follows:

=head2 + (Plus)

The + command indicates the starting of a new reply, and that the immediately following
commands relates to that reply. The data for the + command would be the message trigger
(i.e. "+ hello bot"). Each reply can have only one trigger, however there is a "redirect"
command (see below) to redirect a message to another reply.

=cut

=head2 - (Minus)

The - command indicates the response to the + trigger above it. The - command has many
different uses, however; for example, a single + and a single - can create a single
one-way question/answer response. Or, a single + can have multiple -'s and each - would
be a random response to the input. Or, if you're making a "conversation holder" (see below),
there would be one - as the first message. Or, if you're making a conditional, the -'s would
only be called when the conditionals all returned false.

=cut

=head2 @ (At Symbol)

The @ command is used as a redirect. Each reply set can have only one redirect element.
The data for the redirect would be the message that would be matched by another reply.
For example, if you have a reply to "identify yourself" with the bot's identity, you
could have another trigger "who are you" refer back to "identify yourself" - there's an
example of this, see below.

=cut

=head2 * (Star Symbol)

The * command is for conditionals. A good conditional looks like this: "* if (variable) = (value)",
each element should be separated by a single space. If the elements can't be found, it will not
match correctly. If the "IF" part isn't where it should be, the entire thing will be skipped over.
There's an example of this too, see below.

=cut

=head2 & (Amperstand)

The & command indicates a "conversation holder." One such reply would begin with the + command,
as always, followed immediately by a - command (for the first reply in the chain). All other
commands following would start with an "&" and would be called one at a time until there are
none left. There's a couple examples of this too, see below. Also, this is the one special case
in which the <msg> tag can be included in the replies.

=cut

=head2 # (Pound)

The # command indicates text to be evaluated as Perl code. A response can have as many # commands
as needed, each one is added to the last one (if your code is too complex to be read easily on a
single line, you can go on to multiple lines).

=cut

=head2 > (greater than)

The > command starts a labeled piece of code. For now, is only used for topics.

=cut

=head2 < (less than)

The < command ends a labeled piece of code.

=cut

=head1 Example Reply Code

Here's an example reply code:

  // Test Replies
  
  // A standard reply to "hello", with multiple responses.
  + hello
  - Hello there!
  - What's up?
  - This is random, eh?
  
  // A simple one-reply response to "what's up"
  + what's up
  - Not much, you?
  
  // A test using <star1>
  + say *
  - Um.... "<star1>"
  
  // This reply is referred to below.
  + identify yourself
  - I am Alpha.
  
  // Refers the asker back to the reply above.
  + who are you
  @ identify yourself
  
  // Conditionals Test
  + am i your master
  * if master = 1::Yes, you are my master.
  - No, you are not my master.
  
  // A Conversation Holder: Knock Knock!
  + knock knock
  - Who's there?
  & <msg> who?
  & Ha! <msg>! That's a good one!
  
  // A Conversation Holder: Rambling!
  + are you crazy
  - I was crazy once.
  & They locked me away...
  & In a room with padded walls.
  & There were rats there...
  & Did I mention I was crazy once?
  
  // Topic Test
  + you suck
  - And you're very rude. Apologize now!{topic=apology}
  
  > topic apology
  
    + *
    - No, apologize for being so rude to me.

    // Set {topic=random} to return to the default topic.
    + sorry
    - See, that wasn't too hard. I'll forgive you.{topic=random}
    
  < topic

=cut

=head1 CHANGE LOG

Version 1.32
- Added the ">" and "<" commands, now used for topics.

Version 1.2
- "sort_replies" method added--sorts the replies (normal triggers will be checked before
	wildcards, resulting in better matching!)

Version 1.1
- Fixed bug in reply matching with wildcards.
- Added a "#" command for executing System Commands.

Version 1.0
- Initial Release

=cut

=head1 AUTHOR

Copyright (C) 2004 Cerone Kirsle; kirsle[at]aichaos[dot]com

=cut

1;