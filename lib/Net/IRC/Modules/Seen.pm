use v6;
use Net::IRC::CommandHandler;
use Net::IRC::TextUtil;

class Net::IRC::Modules::Seen does Net::IRC::CommandHandler {
	class Seen {
		has $.when = now;
		has $.what;
		has $.how;
	}
	has %!seen;

	multi method said ( $ev ) {
		%!seen{~$ev.who}  := Seen.new(:how('saying:'), :what(~$ev.what));
	}

	multi method emoted ( $ev ) {
		%!seen{~$ev.who}  := Seen.new(:how("emoting: * $ev.who()"), :what(~$ev.what));
	}

	multi method kicked ( $ev ) {
		%!seen{~$ev.what} := Seen.new(:how('being kicked from'), :what(~$ev.where));
	}

	multi method joined ( $ev ) {
		%!seen{~$ev.who}  := Seen.new(:how('joining'), :what(~$ev.where));
	}

	multi method nickchange ( $ev ) {
		%!seen{~$ev.who}  := Seen.new(:how('changing nick to'), :what(~$ev.what));
		%!seen{~$ev.what} := Seen.new(:how('changing nick from'), :what(~$ev.who));
	}


	method command_seen ( $ev, $/ ) {
		my @params = ($<params> // '').comb(/\S+/);
		if @params {
			for @params -> $nick {
				if %!seen{$nick} -> $seen {
					my $dt	    = DateTime.new($seen.when);
					my $stamp   = $dt.Str.subst('T', ' ');
					my $seconds = now - $seen.when;
					my $elapsed = friendly-duration($seconds);
					
					$ev.msg("$nick was last seen at $stamp ($elapsed ago) $seen.how() $seen.what()");
				}
				else {
					$ev.msg("I haven't seen $nick.");
				}
			}
		}
		else {
			self.usage($ev, 'seen <nick> [<nick> ...]');
		}
	}
}

# vim: ft=perl6 tabstop=4 shiftwidth=4
