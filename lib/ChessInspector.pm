package ChessInspector;

use Chess::Pgn;
use Chess::PGN::Parse;
use Chess::Rep;
use Chess::Rep::Coverage;
use File::Basename;
use List::SomeUtils qw(natatime);
use POSIX qw(ceil);

our $VERSION = '0.01';

=head1 NAME

ChessInspector

=head1 DESCRIPTION

Visualize the potential energy of a chess game

=cut

sub coverage {
    my ( $fen, $pgn, $move, $posn, $prev, $last ) = @_;

    my $results = {};

    # Total moves in game.
    my $moves = 0;

    my ( $white, $black ) = ( '', '' );

    my $last_move;
    my $meta;

    if ( $pgn ) {
        # Set position and number of moves made.
        ( $fen, $moves, $white, $black, $last_move, $meta ) = _fen_from_pgn(
            pgn => $pgn,
            move => $move,
            $fen ? ( fen => $fen ) : (),
        );
    }

    my $g = Chess::Rep::Coverage->new;
    $g->set_from_fen($fen);
    my $c = $g->coverage();

    my $player = {
        white => {
            name       => $white ? $white : '',
            moves_made => 0,
            can_move   => 0,
            threaten   => 0,
            protect    => 0,
            last_move  => '',
        },
        black => {
            name       => $black ? $black : '',
            moves_made => 0,
            can_move   => 0,
            threaten   => 0,
            protect    => 0,
            last_move  => '',
        }
    };

    my %chessfont = (
        wk => '&#9812;',
        wq => '&#9813;',
        wr => '&#9814;',
        wb => '&#9815;',
        wn => '&#9816;',
        wp => '&#9817;',
        bk => '&#9818;',
        bq => '&#9819;',
        br => '&#9820;',
        bb => '&#9821;',
        bn => '&#9822;',
        bp => '&#9823;',
    );

    for my $row ( 1 .. 8 ) {
        for my $col ( 'A' .. 'H' ) {
            # Convenience.
            my $key = $col . $row;

            # Compute the cell occupancy, protection, threat & move state.
            # TODO Use the rep bitmask instead of this hack.
            my $piece = exists $c->{$key}{occupant}
                ? ($c->{$key}{color} ? 'w' : 'b') . lc $c->{$key}{occupant} : '';
            # Convert to a single chess piece character.
            $piece = $chessfont{$piece};

            # Get the cell coverage states
            my $protect = exists $c->{$key}{is_protected_by}
                ? scalar @{ $c->{$key}{is_protected_by} }     : 0;
            my $threat = exists $c->{$key}{is_threatened_by}
                ? scalar @{ $c->{$key}{is_threatened_by} }    : 0;
            my $wmove = exists $c->{$key}{white_can_move_here}
                ? scalar @{ $c->{$key}{white_can_move_here} } : 0;
            my $bmove = exists $c->{$key}{black_can_move_here}
                ? scalar @{ $c->{$key}{black_can_move_here} } : 0;

            # Compute the player stats.
            for my $color ( [ white => 128 ], [ black => 0 ] )
            {
                $player->{$color->[0]}{can_move} += $color->[0] eq 'white' ? $wmove : $bmove;
                $player->{$color->[0]}{threaten} += @{ $c->{$key}{threatens} }
                    if exists $c->{$key}{threatens} && $c->{$key}{color} == $color->[1];
                $player->{$color->[0]}{protect}  += @{ $c->{$key}{protects} }
                    if exists $c->{$key}{protects} && $c->{$key}{color} == $color->[1];
            }

            my $protects         = _get_field_id_list( $c->{$key}{protects} );
            my $is_protected_by  = _get_field_id_list( $c->{$key}{is_protected_by} );
            my $threatens        = _get_field_id_list( $c->{$key}{threatens} );
            my $is_threatened_by = _get_field_id_list( $c->{$key}{is_threatened_by} );

            # Add the cell state to the response.
            push @{ $results->{rows}{$row} }, {
                row            => $row,
                col            => $col,
                position       => $posn,
                previous       => $prev,
                piece          => $piece,
                protected      => $protect,
                threatened     => $threat,
                white_can_move => $wmove,
                black_can_move => $bmove,
                exists $c->{$key}{occupant} ? ( occupant => $c->{$key}{occupant} ) : (),
                exists $c->{$key}{protects} ? ( protects => $protects ) : (),
                exists $c->{$key}{threatens} ? ( threatens => $threatens ) : (),
                exists $c->{$key}{is_protected_by} ? ( is_protected_by => $is_protected_by ) : (),
                exists $c->{$key}{is_threatened_by} ? ( is_threatened_by => $is_threatened_by ) : (),
            };
        }
    }

    # Add the game state to the response.
    $results->{game} = {
        to_move => $g->{to_move},
        fen     => $fen,
        pgn     => $pgn,
        reverse => $move == -1 ? $moves - 1 : $move - 1,
        forward => $move > $moves + 1 ? 0 : $move + 1,
        half    => ceil( $moves / 2 ),
        total   => $moves,
        meta    => $meta,
     };

    # Grab the PGN files
    my @pgn;
    my $pgndir = 'public/pgn/';
    opendir( my $dh, $pgndir ) || die "Can't read $pgndir: $!";
    while( readdir $dh ) {
        next if /^\./;
        my $basename = basename( $_, '.pgn' );
        push @pgn, $basename;

        push @{ $results->{games} },
            {
                name     => $basename,
                selected => $basename eq $pgn ? $basename : 0,
            };
    }
    closedir $dh;

    # Reset the moves to the penultimate, if given the last as arg.
    $move = $moves if $move == -1;

    # Compute the player moves made.
    if ( $move % 2 )
    {
        $player->{black}{moves_made} = ( $move - 1 ) / 2;
        $player->{white}{moves_made} = $player->{black}{moves_made} + 1;

        $player->{white}{last_move} = $move ? $last_move : '';
        $player->{black}{last_move} = $move ? $last : '';
    }
    else
    {
        $player->{white}{moves_made} = $move / 2;
        $player->{black}{moves_made} = $player->{white}{moves_made};

        $player->{black}{last_move} = $move ? $last_move : '';
        $player->{white}{last_move} = $move ? $last : '';
    }

    # Add player status to the response.
    for my $color (qw( white black )) {
        $results->{$color} = $player->{$color};
    }

    return $results;
}

sub _get_field_id_list {
    my $list = shift;
    return join( ', ', sort map { Chess::Rep::get_field_id($_) } @$list );
}

sub _fen_from_pgn {
    my %args = @_;

    # Assume that the PGN is given as a filename without the extension.
    $args{pgn} = 'public/pgn/' . $args{pgn} . '.pgn';

    # Consume the game moves (only).
    my $p = Chess::Pgn->new($args{pgn});
    $p->ReadGame;

    my $meta = {
        result => $p->result,
        site   => $p->site,
        date   => $p->date,
        round  => $p->round,
        event  => $p->{Event},
        eco    => $p->eco,
    };

    my $game = $p->game;
    $game =~ s/\n/ /g; # De-wrap.
    my @pairs = split /\s*\d+\.\s*/, $game; 
    my @moves = ();
    for my $pair (@pairs) {
        next if $pair =~ /^\s*$/;
        last if $pair =~ /{/;
        push @moves, split /\s+/, $pair;
    }

    # Reset the move to the penultimate, if given the last as arg.
    $args{move} = $#moves if $args{move} == -1;

    my $g = Chess::Rep->new;

    # Declare the FEN.
    my $fen = '';

    my $result;
    my $last_move;

    my $i = 0;
    for my $move (@moves) {
        # Are we on the selected move?
        if ( $args{move} == $i ) {
            # Set the FEN.
            $fen = $g->get_fen;

            # Set the last move.
            $last_move = $result->{san};

            last;
        }

        # Make the move.
        $result = $g->go_move($move);

        # Increment our move counter.
        $i++;
    }

    $fen = $args{fen} if $args{fen};

    return $fen, $#moves, $p->white, $p->black, $last_move, $meta;
}

1;

__END__

=head1 AUTHOR
 
Gene Boggs <gene@cpan.org>
 
=head1 COPYRIGHT AND LICENSE
 
This software is copyright (c) 2023 by Gene Boggs.
 
This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
