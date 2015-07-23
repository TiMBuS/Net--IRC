use v6;

enum RequiredIntro is export <
	NONE
	NICK
	PREFIX
	EITHER
	BOTH
>;

enum CommandType is export <Short Long>;
role Command { has $.abbreviate };
multi trait_mod:<is>(Routine:D $m, :cmd(:$command)!) is export {
	$m does Command(abbreviate => ($command !eqv Long));
}

sub abbrev($name) { [\~] $name.comb }

role Net::IRC::CommandHandler {
	has Str $.prefix is rw = '!';
	has RequiredIntro $.required-intro is rw = EITHER;

	has @!cmds = self.^methods.grep(Command);

	has %cmd-names   = @!cmds.map({ $^n.name => $^n });
	has %short-names = {}.push( 
		@!cmds.grep(*.abbreviate).map({ abbrev($^n.name) X=> $^n })
	);

	method recognized($handler: $ev) {
		return $ev.cache<CommandHandler>{$handler.prefix} //= (gather {
			$ev.what ~~ token {
				# Intro
				^
				[ \s* $<nick>=("$ev.state()<nick>") [ <[:,]> | \s ] ]? \s*
				[ $<prefix>=("$handler.prefix()") \s* ]?

				# Actual command (and optional params)
				$<command>=(\w+) [ <?> | \s+ $<params>=(.*) ]
				$
			} or take False;

			# Let private chat act as specifying the bot's nick
			my $nick = $<nick> || $ev.where eq $ev.state<nick>;

			given $.required-intro {
				when NICK   { take False unless $nick              }
				when PREFIX { take False unless $<prefix>          }
				when EITHER { take False unless $<prefix> || $nick }
				when BOTH   { take False unless $<prefix> && $nick }
			}

			take $/;
		})[0];
	}

	multi method said ($ev where { $/ := $.recognized($ev) }) {
		self!dispatch($<command>, $ev, $/);
	}

	method !dispatch($name, *@args) {
		given %cmd-names{$name} // %short-names{$name} {
			when Callable   { .(self, |@args) }
			when Positional { warn "Cannot disambiguate '$name'. Possible commands: {$_>>.name.join(', ')}" }
			default         { warn 'Nothing to dispatch!' }
		}
	}

	method usage($ev, $usage) {
		$ev.msg("Usage: $usage");
	}
}

# vim: ft=perl6 tabstop=4 shiftwidth=4
