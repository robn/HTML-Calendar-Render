package HTML::Calendar::Render;

use warnings;
use strict;

use Carp;
use Time::Local;
use Date::Calc qw(Days_in_Month Day_of_Week);
use POSIX qw(strftime);

our @day_names = ( 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' );

sub _setup_render_options {
    my (%args) = @_;

    my $opts = {
        segments_per_hour => $args{segments_per_hour} || 4,
        start_hour        => $args{start_hour}        || 9,
        end_hour          => $args{end_hour}          || 17,
        best_fit          => $args{best_fit}          ? 1 : 0,
        fixed_width       => $args{fixed_width}       ? 1 : 0,
    };

    if (60 / $opts->{segments_per_hour} != int(60 / $opts->{segments_per_hour})) {
        croak "segments_per_hour must divide evenly into 60";
    }
    $opts->{segment_mins} = int(60 / $opts->{segments_per_hour});

    croak "start_hour must be between 0 and 23" if $opts->{start_hour} < 0 or $opts->{start_hour} > 23;
    croak "start_hour must be an integer" if $opts->{start_hour} != int($opts->{start_hour});

    croak "end_hour must be between 1 and 24" if $opts->{end_hour} < 0 or $opts->{end_hour} > 23;
    croak "end_hour must be an integer" if $opts->{end_hour} != int($opts->{end_hour});

    return $opts;
}
    
sub new {
    my $class = shift;

    my $self = {
        renderopts => _setup_render_options(@_),
    };

    return bless $self, $class;
}

sub add_event {
    my ($self, %args) = @_;

    my ($start, $end) = @args{qw(start end)};

    # no times provided. its an all day event, today
    if (!$start && !$end) {
        $start = timelocal(0,0,0,(localtime)[3,4,5]);
        $end = 0;
    }

    # only start provided. all day event on that day
    elsif ($start && !$end) {
        $start = timelocal(0,0,0,(localtime($start))[3,4,5]);
        $end = 0;
    }

    # only end provided. all day event on that day
    elsif (!$start && $end) {
        $start = timelocal(0,0,0,(localtime($end))[3,4,5]);
        $end = 0;
    }

    # start and end provided, but end before start. all day event on start day
    elsif ($end < $start) {
        $start = timelocal(0,0,0,(localtime($start))[3,4,5]);
        $end = 0;
    }

    my %event = (
        title => $args{title} || "Untitled",
        start => $start,
        end   => $end,
    );

    $event{location} = $args{location} if $args{location};
    $event{text}     = $args{text}     if $args{text};
    $event{id}       = $args{id}       if $args{id};

    if ($end == 0) {
        push @{$self->{events}->{$start}->{$end}}, \%event;
    }

    else {
        # store times along segment boundaries
        my ($sec, $min, $hour, $mday, $mon, $year) = localtime($start);

        $sec = 0;
        $min = int($min / $self->{renderopts}->{segment_mins} + 0.5) * $self->{renderopts}->{segment_mins};

        my $seg_start = timelocal($sec, $min, $hour, $mday, $mon, $year);

        ($sec, $min, $hour, $mday, $mon, $year) = localtime($end);

        $sec = 0;
        $min = int($min / $self->{renderopts}->{segment_mins} + 0.5) * $self->{renderopts}->{segment_mins};

        my $seg_end = timelocal($sec, $min, $hour, $mday, $mon, $year);

        push @{$self->{events}->{$seg_start}->{$seg_end}}, \%event;
    }
}

sub _gcd {
    my ($a, $b) = @_;
    return $a if $b == 0;
    return _gcd($b, $a % $b);
};

sub _lcm {
    my ($a, $b) = (shift, shift);
    return ($a * $b) / _gcd($a, $b) if scalar @_ == 0;
    return _lcm(($a * $b) / _gcd($a, $b), @_);
};

sub render_event {
    my ($self, $event) = @_;

    my $out;

    $out .= "<div class='calendar-event'";
    $out .= " id='calendar-id-" . $event->{id} . "'" if $event->{id};
    $out .= ">";

    $out .= "<p><span class='calendar-event-title'>" . $event->{title} . "</span>";
    $out .= "<br /><span class='calendar-event-location'>(" . $event->{location} . ")</span>" if $event->{location};
    $out .= "</p>";

    $out .= "<p class='calendar-event-text'>" . $event->{text} . "</p>" if $event->{text};

    $out .= "</div>";

# XXX resurrect this kind of thing   
#    if($self->{'opts'}->{'show_description'} and $event->{'description'}) {
#        $out .= "<p class='event-description'>" . substr($event->{'description'}, 0, $self->{'opts'}->{'max_description'}) . "</p>";
#    }

    return $out;
};

sub render_summary {
    my ($self, $day_start) = @_;

    my @day_events;
    my @allday_events;

    my $flag = 0;

    for my $event_start (sort { $a <=> $b } keys %{$self->{events}}) {
        next if $event_start < $day_start or $event_start >= $day_start + 86400;

        $flag = 1;

        for my $event_end (sort { $a <=> $b } keys %{$self->{events}->{$event_start}}) {
            if($event_end == 0) {
                push @allday_events, @{$self->{events}->{$event_start}->{0}};
            } else {
                push @day_events, @{$self->{events}->{$event_start}->{$event_end}};
            }
        }
    }

    return if not $flag;

    my $out;

    my $hr = 0;

    if(scalar @allday_events > 0) {
        $out .= "<p class='calendar-summary-start-end'>All day</p>";

        for my $event (@allday_events) {
            if($hr) {
                $out .= "<hr />";
            } else {
                $hr = 1;
            }

            $out .= $self->render_event($event);
        }
    }

    if(scalar @day_events) {
        for my $event (@day_events) {
            if($hr) {
                $out .= "<hr />";
            } else {
                $hr = 1;
            }

            $out .=
                "<p class='calendar-summary-start-end'>" .
                strftime('%l:%M', localtime($event->{start})) . " - " .
                strftime('%l:%M', localtime($event->{end})) .
                "</p>";
                    
            $out .= $self->render_event($event);
        }
    }

    return $out;
}

sub render_days {
    my ($self, $start, $days) = @_;

    $days--;

    # get start back to the start of the day
    $start = timelocal(0,0,0, (localtime($start))[3,4,5]);

    # figure out where our table starts and ends on
    my ($start_segment, $end_segment);
    if($self->{renderopts}->{best_fit}) {
        $start_segment = 23 * $self->{renderopts}->{segments_per_hour};
        $end_segment = 0;
    } else {
        $start_segment = $self->{renderopts}->{start_hour} * $self->{renderopts}->{segments_per_hour};
        $end_segment = $self->{renderopts}->{end_hour} * $self->{renderopts}->{segments_per_hour};
    }

    for my $es (keys %{$self->{events}}) {
        next if $es < $start or $es >= $start + 86400;

        # ignore it if there's only all-day events here
        next if defined $self->{events}->{$es}->{0} and scalar keys %{$self->{events}->{$es}} == 1;

        my ($min, $hour) = (localtime($es))[1,2];
        my $segment = $hour * $self->{renderopts}->{segments_per_hour} + ($min / $self->{renderopts}->{segment_mins});
        $start_segment = $segment if $segment < $start_segment;

        for my $ee (keys %{$self->{events}->{$es}}) {
            next if $ee == 0;

            my ($min, $hour) = (localtime($ee))[1,2];
            my $segment = $hour * $self->{renderopts}->{segments_per_hour} + ($min / $self->{renderopts}->{segment_mins});
            $end_segment = $segment if $segment > $end_segment;
        }
    }

    # each hour of the day is split into a number of segments
    # we generate an list of segments for each day
    # each list element holds a list of events that exist in that segment
    my $num_segments = $end_segment - $start_segment;
    my @segments;

    my @allday;
    my @day_meta;

    for my $day (0 .. $days) {
        # start of day
        my $day_start = $start + ($day * 86400);

        # get the all-day events out
        for my $event_start (keys %{$self->{events}}) {
            next if not defined $self->{events}->{$event_start}->{0};

            next if $event_start < $day_start or $event_start >= $day_start + 86400;

            for my $event (@{$self->{events}->{$event_start}->{0}}) {
                push @{$allday[$day]}, $event;
            }
        }

        # time of the first segment in our table
        $day_start += ($start_segment * $self->{renderopts}->{segment_mins} * 60);

        for my $segment (0 .. $num_segments - 1) {
            # time bounds for this segment
            my $segment_start = $day_start + ($segment * $self->{renderopts}->{segment_mins} * 60);
            my $segment_end = $segment_start + $self->{renderopts}->{segment_mins} * 60;

            # find events that start in this segment
            for my $event_start (keys %{$self->{events}}) {
                next if $event_start < $segment_start or $event_start >= $segment_end;

                # check each event that starts here
                for my $event_end (keys %{$self->{events}->{$event_start}}) {
                    # ignore all-day events
                    next if $event_end == 0;

                    # figure out how many segments each event occupies
                    my $event_segments = int(($event_end - $event_start) / ($self->{renderopts}->{segment_mins} * 60) + 0.5);

                    # link the event into this segment
                    for my $event_segment (0 .. $event_segments - 1) {
                        for my $event (@{$self->{events}->{$event_start}->{$event_end}}) {
                            $event->{segment_start} = $segment;
                            $event->{segments} = $event_segments;

                            push @{$segments[$day]->[$segment + $event_segment]}, $event;
                        }
                    }
                }
            }

            # number of events on this segment
            if($segments[$day]->[$segment]) {
                my $num_events = scalar @{$segments[$day]->[$segment]};
                push @{$day_meta[$day]->{events}}, $num_events;
            }

        }

        # figure out segment widths
        my %overlap_events;
        my $max_overlap = 0;
        my $max_events = 0;
        my $top_segment = 0;

        for my $segment (0 .. $num_segments) {
            $max_overlap = scalar keys %overlap_events if $max_overlap < scalar keys %overlap_events;

            # if this segment has no events, or we've run off the end, we can reset
            if($segment == $num_segments or
              ($segments[$day]->[$segment] and scalar @{$segments[$day]->[$segment]} == 0)) {

                # reset. we run back up the segment list, recording the number of
                # overlapping events for each segment between here and the top

                for my $span_segment ($top_segment .. $segment - 1) {
                    $day_meta[$day]->{num_events}->[$span_segment] = $max_overlap;
                }

                $top_segment = $segment;
            
                $max_events = $max_overlap if $max_events < $max_overlap;
                undef %overlap_events;
                $max_overlap = 0;

                next;
            }

            # forget about events that have ended
            my %segment_events;
            for my $event (@{$segments[$day]->[$segment]}) {
                $segment_events{$event} = 1;
            }
            for my $event (keys %overlap_events) {
                delete $overlap_events{$event} if not $segment_events{$event};
            }

            # if the events on this line have never been seen before, then we can reset
            my $seen = 0;
            for my $event (@{$segments[$day]->[$segment]}) {
                $seen = 1 if $overlap_events{$event};
            }
            if(not $seen) {
                for my $span_segment ($top_segment .. $segment - 1) {
                    $day_meta[$day]->{num_events}->[$span_segment] = $max_overlap;
                }

                $top_segment = $segment;

                $max_events = $max_overlap if $max_events < $max_overlap;
                undef %overlap_events;
                $max_overlap = 0;
            }
            
            # keep track of events
            for my $event (@{$segments[$day]->[$segment]}) {
                $overlap_events{$event} = 1;
            }
        }

        # got it
        $day_meta[$day]->{max_events} = $max_events;

        if(not $day_meta[$day]->{events}) {
            $day_meta[$day]->{span} = 1;
        } else {
            $day_meta[$day]->{span} = _lcm(@{$day_meta[$day]->{events}}, $max_events);

            $day_meta[$day]->{event_span} = $day_meta[$day]->{span} / $max_events;
        }
        
        $day_meta[$day]->{slots} = [ ];
    }

    my $col_width = int(92 / ($days + 1));              # XXX constants
    my $time_width = 100 - $col_width * ($days + 1);    # XXX constants

    my $out =
        "<table class='calendar' width='100%' border='1' cellpadding='2' cellspacing='0'" . ($self->{renderopts}->{fixed_width} ? " style='table-layout: fixed'" : '') . ">\n" .
        "<tr class='calendar-date-bar'><td width='$time_width%'></td>";

    for my $day (0 .. $days) {
        my $epoch = $start + $day * 86400;
        my @lt = localtime($epoch);

        my $span = $day_meta[$day]->{span};
        $out .=
            "<td colspan='$span' width='$col_width%'>" .
            strftime('%A', @lt) . " " .
            $lt[3] . " " .
            strftime('%B', @lt) .
            "</td>";
    }

    $out .= "</tr>\n";

    # plug in all-day events if necessary
    if(scalar @allday > 0) {
        $out .= "<tr valign='top'><td align='right' class='calendar-hours-allday'>All day</td>";

        for my $day (0 .. $days) {
            my $span = $day_meta[$day]->{span};

            if(defined $allday[$day]) {
                $out .= "<td colspan='$span' class='calendar-event-cell' bgcolor='#cccccc'>";
            
                for my $event (@{$allday[$day]}) {
                    $out .= $self->render_event($event);
                }

                $out .= "</td>";
            }
            
            else {
                $out .= "<td colspan='$span'>&nbsp;</td>";
            }
        }

        $out .= "</tr>\n";
    }

    my $hour = $start_segment / $self->{renderopts}->{segments_per_hour};
    my $hour_segment = 0;
    for my $segment (0 .. $num_segments - 1) {
        $out .= "<tr valign='top'>";

        if($hour_segment == 0) {
            $out .=
                "<td align='right' class='calendar-hours'>" .
                ($hour > 12 ? sprintf('%d', $hour - 12) : ($hour == 0 ? "12" : $hour)) .
                ($hour < 12  ? "am"    : "pm") .
                "</td>";
            $hour++;
        } else {
            $out .= "<td align='right' class='calendar-minutes'>" . sprintf('%d', $hour_segment * $self->{renderopts}->{segment_mins}) . "</td>";
        }

        $hour_segment++;
        $hour_segment = 0 if $hour_segment == $self->{renderopts}->{segments_per_hour};

        for my $day (0 .. $days) {
            my $events = $segments[$day]->[$segment];

            my $span = $day_meta[$day]->{span};
            my $max_events = $day_meta[$day]->{max_events};
            my $slots = $day_meta[$day]->{slots};

            # clean up slots
            for my $slot (0 .. $max_events - 1) {
                next if not defined $slots->[$slot];

                $slots->[$slot] = undef if $slots->[$slot]->{segment_start} + $slots->[$slot]->{segments} == $segment;
            }

            # no events in this segment - blank box
            if(scalar @$events == 0) {
                $out .= "<td colspan='$span'>&nbsp;</td>";
            }

            # some events
            else {

                # insert new events
                for my $event (@$events) {
                    # only interested in events that start here
                    next if $event->{segment_start} != $segment;

                    # got the column width
                    my $num_events = $day_meta[$day]->{num_events}->[$segment];
                    $event->{colspan} = $span / $num_events;

                    # find empty slots and fill them
                    my $fill_slots = 0;
                    for my $slot (0 .. $max_events - 1) {
                        if(not defined $slots->[$slot]) {
                            $slots->[$slot] = $event;
                            last if $fill_slots == ($max_events - $num_events);
                            $fill_slots++;
                        }
                    }
                }

                my $colspan = 0;

                # render slots
                my $empty = 0;

                for my $slot (0 .. $max_events - 1) {

                    # if there's nothing in the current slot, just blank it out
                    if(not defined $slots->[$slot]) {
                        $empty++;
                        $colspan += $day_meta[$day]->{event_span};
                    }
                    
                    # there's an event here
                    else {
                        # close the gap
                        if($empty) {
                            $out .= "<td colspan='" . $empty * $day_meta[$day]->{event_span} . "'>&nbsp;</td>";
                            $empty = 0;
                        }

                        # event starts here, render it
                        if($slots->[$slot]->{segment_start} == $segment) {

                            my $event = $slots->[$slot];

                            $out .= "<td class='calendar-event-cell' colspan='" . $event->{colspan} . "' rowspan='" . $event->{segments} . "' bgcolor='#cccccc'>";

                            $out .= "<span class='calendar-event-cell-timestamp'>" . strftime('%l:%M', localtime($event->{start})) . " - " . strftime('%l:%M', localtime($event->{end})) . "</span>";
                    
                            $out .= $self->render_event($event);

                            $colspan += $event->{colspan};
                        }
                    }

                    # don't render off the edge of the day
                    last if $colspan >= $span;
                }

                # close the gap
                if($empty) {
                    $out .= "<td colspan='" . $empty * $day_meta[$day]->{event_span} . "'>&nbsp;</td>";
                    $empty = 0;
                }
            }
        }

        $out .= "</tr>\n";
    }

    $out .= "</table>\n";

    return $out;
}

sub render_month {
    my ($self, $start) = @_;

    my $out =
        "<table class='calendar' width='100%' border='1' cellpadding='2' cellspacing='0'" . ($self->{renderopts}->{fixed_width} ? " style='table-layout: fixed'" : '') . ">\n" .
        "<tr class='calendar-date-bar'>";

    for my $day (0..6) {
        $out .= "<td width='14%'>" . $day_names[$day] . "</td>";
    }

    $out .= "</tr>\n";

    my ($year, $month) = (localtime $start) [ 5, 4 ];
    $year += 1900; $month++;
    my $month_days = Days_in_Month($year, $month);

    $out .= "<tr valign='top'>";

    my $column = Day_of_Week($year, $month, 1);
    $column = 0 if $column == 7;

    if($column > 0) {
        $out .= "<td colspan='$column'></td>";
    }

    for my $day (0 .. $month_days - 1) {
        my $summary_out = $self->render_summary(timelocal(0, 0, 0, $day+1, $month-1, $year-1900));

        if(not $summary_out) {
            $out .= "<td><span class='calendar-month-date'>" . sprintf('%d', $day + 1) . "</span>";
        }
        
        else {
            $out .=
                "<td class='calendar-month-event-cell' bgcolor='#cccccc'>" .
                "<span class='calendar-month-date'>" . sprintf('%d', $day + 1) . "</span>" .
                $summary_out;
        }

        $out .= "</td>";

        $column++;
        if($column == 7) {
            $out .=
                "</tr>\n" .
                "<tr valign='top'>";

            $column = 0;
        }
    }

    if($column > 0) {
        $out .= "<td colspan='" . (7 - $column) . "'></td>";
    }

    $out .=
        "</tr>\n" .
        "</table>";

    return $out;
}

1;
