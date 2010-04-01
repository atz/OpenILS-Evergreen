package OpenILS::Application::Acq::Search;
use base "OpenILS::Application";

use strict;
use warnings;

use OpenILS::Event;
use OpenILS::Utils::CStoreEditor q/:funcs/;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Application::Acq::Lineitem;
use OpenILS::Application::Acq::Financials;
use OpenILS::Application::Acq::Picklist;

my %RETRIEVERS = (
    "lineitem" =>
        \&{"OpenILS::Application::Acq::Lineitem::retrieve_lineitem_impl"},
    "picklist" =>
        \&{"OpenILS::Application::Acq::Picklist::retrieve_picklist_impl"},
    "purchase_order" => \&{
        "OpenILS::Application::Acq::Financials::retrieve_purchase_order_impl"
    }
);

sub F { $Fieldmapper::fieldmap->{"Fieldmapper::" . $_[0]}; }

# This subroutine returns 1 if the argument is a) a scalar OR
# b) an array of ONLY scalars. Otherwise it returns 0.
sub check_1d_max {
    my ($o) = @_;
    return 1 unless ref $o;
    if (ref($o) eq "ARRAY") {
        foreach (@$o) { return 0 if ref $_; }
        return 1;
    }
    0;
}

# Returns 1 if and only if argument is an array of exactly two scalars.
sub could_be_range {
    my ($o) = @_;
    if (ref $o eq "ARRAY") {
        return 1 if (scalar(@$o) == 2 && (!ref $o->[0] && !ref $o->[1]));
    }
    0;
}

sub prepare_acqlia_search_and {
    my ($acqlia) = @_;

    my @phrases = ();
    foreach my $unit (@{$acqlia}) {
        my $something = 0;
        my $subquery = {
            "select" => {"acqlia" => ["id"]},
            "from" => "acqlia",
            "where" => {"-and" => [{"lineitem" => {"=" => {"+jub" => "id"}}}]}
        };

        while (my ($k, $v) = each %$unit) {
            my $point = $subquery->{"where"}->{"-and"};
            if ($k !~ /^__/) {
                push @$point, {"definition" => $k};
                $something++;

                if ($unit->{"__fuzzy"} and not ref $v) {
                    push @$point, {"attr_value" => {"ilike" => "%" . $v . "%"}};
                } elsif ($unit->{"__between"} and could_be_range($v)) {
                    push @$point, {"attr_value" => {"between" => $v}};
                } elsif (check_1d_max($v)) {
                    push @$point, {"attr_value" => $v};
                } else {
                    $something--;
                }
            }
        }
        push @phrases, {"-exists" => $subquery} if $something;
    }
    @phrases;
}

sub prepare_acqlia_search_or {
    my ($acqlia) = @_;

    my $point = [];
    my $result = {"+acqlia" => {"-or" => $point}};

    foreach my $unit (@$acqlia) {
        my ($k, $v, $fuzzy, $between) = breakdown_term($unit);
        if ($fuzzy and not ref $v) {
            push @$point, {
                "-and" => {
                    "definition" => $k,
                    "attr_value" => {"ilike" => "%" . $v . "%"}
                }
            };
        } elsif ($between and could_be_range($v)) {
            push @$point, {
                "-and" => {
                    "definition" => $k, "attr_value" => {"between" => $v}
                }
            };
        } elsif (check_1d_max($v)) {
            push @$point, {
                "-and" => {"definition" => $k, "attr_value" => $v}
            };
        }
    }
    $result;
}

sub breakdown_term {
    my ($term) = @_;

    my $key = (grep { !/^__/ } keys %$term)[0];
    (
        $key, $term->{$key},
        $term->{"__fuzzy"} ? 1 : 0,
        $term->{"__between"} ? 1 : 0
    );
}

sub get_fm_links_by_hint {
    my ($hint) = @_;
    foreach my $field (values %{$Fieldmapper::fieldmap}) {
        return $field->{"links"} if $field->{"hint"} eq $hint;
    }
    undef;
}

sub gen_au_term {
    my ($value, $n) = @_;
    +{
        "-or" => {
            "+au$n" => {
                "-or" => {
                    "usrname" => $value,
                    "alias" => $value,
                    "first_given_name" => $value,
                    "second_given_name" => $value,
                    "family_name" => $value
                }
            },
            "+ac$n" => {"barcode" => $value}
        }
    };
}

# go through the terms hash, find keys that correspond to fields links
# to actor.usr, and rewrite the search as one that searches not by
# actor.usr.id but by any of these user properties: card barcode, username,
# alias, given names and family name.
sub prepare_au_terms {
    my ($terms, $join_num) = @_;
    my @joins = ();
    $join_num ||= 0;

    foreach my $conj (qw/-and -or/) {
        next unless exists $terms->{$conj};

        my @new_outer_terms = ();
        foreach my $hint_unit (@{$terms->{$conj}}) {
            my $hint = (keys %$hint_unit)[0];
            (my $plain_hint = $hint) =~ y/+//d;

            if (my $links = get_fm_links_by_hint($plain_hint) and
                $plain_hint ne "acqlia") {
                my @new_terms = ();
                foreach my $pair (@{$hint_unit->{$hint}}) {
                    my ($attr, $value) = breakdown_term($pair);
                    if ($links->{$attr} and
                        $links->{$attr}->{"class"} eq "au") {
                        push @joins, [$plain_hint, $attr, $join_num];
                        push @new_outer_terms, gen_au_term($value, $join_num);
                        $join_num++;
                    } else {
                        push @new_terms, $pair;
                    }
                }
                if (@new_terms) {
                    $hint_unit->{$hint} = [ @new_terms ];
                } else {
                    delete $hint_unit->{$hint};
                }
            }
            push @new_outer_terms, $hint_unit if scalar keys %$hint_unit;
        }
        $terms->{$conj} = [ @new_outer_terms ];
    }
    @joins;
}

sub prepare_terms {
    my ($terms, $is_and) = @_;

    my $conj = $is_and ? "-and" : "-or";
    my $outer_clause = {};

    foreach my $class (qw/acqpo acqpl jub/) {
        next if not exists $terms->{$class};

        my $clause = [];
        $outer_clause->{$conj} = [] unless $outer_clause->{$conj};
        foreach my $unit (@{$terms->{$class}}) {
            my ($k, $v, $fuzzy, $between) = breakdown_term($unit);
            if ($fuzzy and not ref $v) {
                push @$clause, {$k => {"ilike" => "%" . $v . "%"}};
            } elsif ($between and could_be_range($v)) {
                push @$clause, {$k => {"between" => $v}};
            } elsif (check_1d_max($v)) {
                push @$clause, {$k => $v};
            }
        }
        push @{$outer_clause->{$conj}}, {"+" . $class => $clause};
    }

    if ($terms->{"acqlia"}) {
        push @{$outer_clause->{$conj}},
            $is_and ? prepare_acqlia_search_and($terms->{"acqlia"}) :
                prepare_acqlia_search_or($terms->{"acqlia"});
    }

    return undef unless scalar keys %$outer_clause;
    $outer_clause;
}

sub add_au_joins {
    my ($from) = shift;

    my $n = 0;
    foreach my $join (@_) {
        my ($hint, $attr, $num) = @$join;
        my $start = $hint eq "jub" ? $from->{$hint} : $from->{"jub"}->{$hint};
        my $clause = {
            "class" => "au",
            "type" => "left",
            "field" => "id",
            "fkey" => $attr,
            "join" => {
                "ac$num" => {
                    "class" => "ac",
                    "type" => "left",
                    "field" => "id",
                    "fkey" => "card"
                }
            }
        };
        if ($hint eq "jub") {
            $start->{"au$num"} = $clause;
        } else {
            $start->{"join"} ||= {};
            $start->{"join"}->{"au$num"} = $clause;
        }
        $n++;
    }
    $n;
}

__PACKAGE__->register_method(
    method    => "unified_search",
    api_name  => "open-ils.acq.lineitem.unified_search",
    stream    => 1,
    signature => {
        desc   => q/Returns lineitems based on flexible search terms./,
        params => [
            {desc => "Authentication token", type => "string"},
            {desc => "Field/value pairs for AND'ing", type => "object"},
            {desc => "Field/value pairs for OR'ing", type => "object"},
            {desc => "Conjunction between AND pairs and OR pairs " .
                "(can be 'and' or 'or')", type => "string"},
            {desc => "Retrieval options (clear_marc, flesh_notes, etc) " .
                "- XXX detail all the options",
                type => "object"}
        ],
        return => {desc => "A stream of LIs on success, Event on failure"}
    }
);

__PACKAGE__->register_method(
    method    => "unified_search",
    api_name  => "open-ils.acq.purchase_order.unified_search",
    stream    => 1,
    signature => {
        desc   => q/Returns purchase orders based on flexible search terms.
            See open-ils.acq.lineitem.unified_search/,
        return => {desc => "A stream of POs on success, Event on failure"}
    }
);

__PACKAGE__->register_method(
    method    => "unified_search",
    api_name  => "open-ils.acq.picklist.unified_search",
    stream    => 1,
    signature => {
        desc   => q/Returns pick lists based on flexible search terms.
            See open-ils.acq.lineitem.unified_search/,
        return => {desc => "A stream of PLs on success, Event on failure"}
    }
);

sub unified_search {
    my ($self, $conn, $auth, $and_terms, $or_terms, $conj, $options) = @_;
    $options ||= {};

    my $e = new_editor("authtoken" => $auth);
    return $e->die_event unless $e->checkauth;

    # What kind of object are we returning? Important: (\w+) had better be
    # a legit acq classname particle, so don't register any crazy api_names.
    my $ret_type = ($self->api_name =~ /cq.(\w+).un/)[0];
    my $retriever = $RETRIEVERS{$ret_type};
    my $hint = F("acq::$ret_type")->{"hint"};

    my $query = {
        "select" => {
            $hint =>
                [{"column" => "id", "transform" => "distinct"}]
        },
        "from" => {
            "jub" => {
                "acqpo" => {
                    "type" => "full",
                    "field" => "id",
                    "fkey" => "purchase_order"
                },
                "acqpl" => {
                    "type" => "full",
                    "field" => "id",
                    "fkey" => "picklist"
                }
            }
        },
        "order_by" => { $hint => {"id" => {}}},
        "offset" => ($options->{"offset"} || 0)
    };

    $query->{"limit"} = $options->{"limit"} if $options->{"limit"};

    $and_terms = prepare_terms($and_terms, 1);
    $or_terms = prepare_terms($or_terms, 0) and do {
        $query->{"from"}->{"jub"}->{"acqlia"} = {
            "type" => "left", "field" => "lineitem", "fkey" => "id",
        };
    };

    my $offset = add_au_joins($query->{"from"}, prepare_au_terms($and_terms));
    add_au_joins($query->{"from"}, prepare_au_terms($or_terms, $offset));

    if ($and_terms and $or_terms) {
        $query->{"where"} = {
            "-" . (lc $conj eq "or" ? "or" : "and") => [$and_terms, $or_terms]
        };
    } elsif ($and_terms) {
        $query->{"where"} = $and_terms;
    } elsif ($or_terms) {
        $query->{"where"} = $or_terms;
    } else {
        $e->disconnect;
        return new OpenILS::Event("BAD_PARAMS", "desc" => "No usable terms");
    }

    my $results = $e->json_query($query) or return $e->die_event;
    $conn->respond($retriever->($e, $_->{"id"}, $options)) foreach (@$results);
    $e->disconnect;
    undef;
}

1;