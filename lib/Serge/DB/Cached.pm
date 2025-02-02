package Serge::DB::Cached;
use parent Serge::DB;

use strict;

no warnings qw(uninitialized);

use Digest::MD5 qw(md5);
use Encode qw(encode_utf8);
use Serge::Util qw(generate_key);


my $DEBUG = undef;

sub open {
    my ($self, $source, $username, $password) = @_;

    # if parameters din't change, just stay connected
    # to the previously opened database

    if (exists $self->{dsn} and
        ($self->{dsn}->{source} eq $source) and
        ($self->{dsn}->{username} eq $username) and
        ($self->{dsn}->{password} eq $password)) {
        print "Reusing previously opened database connection\n";
        return $self->{dbh};
    }

    $self->close if $self->{dbh};

    $self->{dsn} = {
        source => $source,
        username => $username,
        password => $password
    };

    $self->{cache} = {};

    return $self->SUPER::open($source, $username, $password);
}

sub close {
    my ($self) = @_;
    $self->{cache} = {};
    delete $self->{dsn};
    return $self->SUPER::close;
}

sub _copy_props {
    my ($self, $h_old, $h_new) = @_;

    ##################
    #use Data::Dumper; print "::_copy_props\nOld:\n".Dumper($h_old)."\nNew:\n".Dumper($h_new)."\n";
    ##################

    my $result = undef;
    foreach (keys %$h_new) {
        $result = 1 if $h_new->{$_} ne $h_old->{$_};
        ##################
        #print "Changed key: $_\n" if $h_new->{$_} ne $h_old->{$_};
        ##################
        $h_old->{$_} = $h_new->{$_};
    }
    ##################
    #print "Result: $result\n";
    ##################

    return $result;
}

#
#  strings
#

sub get_string_id {
    my ($self, $string, $context, $nocreate) = @_;

    #print "::get_string_id\n" if $DEBUG;

    my $key = 'string_id:'.generate_key($string, $context);

    if (exists $self->{cache}->{$key}) {
        my $id = $self->{cache}->{$key};
        return $id if $id or $nocreate;
    }

    return $self->{cache}->{$key} = $self->SUPER::get_string_id($string, $context, $nocreate);
}

sub update_string_props {
    my ($self, $string_id, $props) = @_;

    #print "::update_string_props\n" if $DEBUG;

    my $key = "string:$string_id";

    my $h = $self->{cache}->{$key};
    $h = $self->{cache}->{$key} = $self->SUPER::get_string_props($string_id) unless $h;

    return $self->SUPER::update_string_props($string_id, $props) if $self->_copy_props($h, $props);
}

sub get_string_props {
    my ($self, $string_id) = @_;

    #print "::get_string_props\n" if $DEBUG;

    my $key = "string:$string_id";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};

    return $self->{cache}->{$key} = $self->SUPER::get_string_props($string_id);
}

#
#  items
#

sub get_item_id {
    my ($self, $file_id, $string_id, $hint, $nocreate) = @_;

    #print "::get_item_id(file_id=$file_id, string_id=$string_id)\n";

    my $key = "item_id:$file_id:$string_id";

    if (exists $self->{cache}->{$key}) {
        my $id = $self->{cache}->{$key};
        return $id if $id or $nocreate;
    }

    # now check if the file was preloaded in the cache,
    # and if it was (which means that all known item_id should
    # also be there in the cache, then return undef if $nocreate flag is set

    my $file_key = "file:$file_id";

    if (exists $self->{cache}->{$file_key}) {
        return undef if $nocreate;
    }

    $hint = undef if $hint eq '';

    return $self->{cache}->{$key} = $self->SUPER::get_item_id($file_id, $string_id, $hint, $nocreate);
}

sub update_item_props {
    my ($self, $item_id, $props) = @_;

    #print "::update_item_props\n" if $DEBUG;

    my $key = "item:$item_id";

    my $h = $self->{cache}->{$key};
    $h = $self->{cache}->{$key} = $self->SUPER::get_item_props($item_id) unless $h;

    return $self->SUPER::update_item_props($item_id, $props) if $self->_copy_props($h, $props);
}

sub get_item_props {
    my ($self, $item_id) = @_;

    #print "::get_item_props\n" if $DEBUG;

    my $key = "item:$item_id";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};

    return $self->{cache}->{$key} = $self->SUPER::get_item_props($item_id);
}

#
#  files
#

sub get_file_id {
    my ($self, $namespace, $job, $path, $nocreate) = @_;

    #print "::get_file_id\n" if $DEBUG;

    my $key = 'file_id:'.md5(encode_utf8(join("\001", ($namespace, $job, $path))));

    if (exists $self->{cache}->{$key}) {
        my $id = $self->{cache}->{$key};
        return $id if $id or $nocreate;
    }

    return $self->{cache}->{$key} = $self->SUPER::get_file_id($namespace, $job, $path, $nocreate);
}

sub update_file_props {
    my ($self, $file_id, $props) = @_;

    #print "::update_file_props (file_id=$file_id)\n";
    #use Data::Dumper;
    #print Dumper($props);

    my $key = "file:$file_id";

    my $h = $self->{cache}->{$key};
    $h = $self->{cache}->{$key} = $self->SUPER::get_file_props($file_id) unless $h;

    return $self->SUPER::update_file_props($file_id, $props) if $self->_copy_props($h, $props);
}

sub get_file_props {
    my ($self, $file_id) = @_;

    #print "::get_file_props\n" if $DEBUG;

    my $key = "file:$file_id";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};

    return $self->{cache}->{$key} = $self->SUPER::get_file_props($file_id);
}

#
#  translations
#

sub get_translation_id {
    my ($self, $item_id, $lang, $string, $fuzzy, $comment, $merge, $nocreate) = @_;

    #print "::get_translation_id\n";

    my $key = "translation_id:$item_id:$lang";

    if (exists $self->{cache}->{$key}) {
        my $id = $self->{cache}->{$key};
        return $id if $id or $nocreate;
    }

    #print "::get_translation_id - key 'translation_id:$item_id:$lang' MISSING FROM CACHE\n";

    return $self->{cache}->{$key} = $self->SUPER::get_translation_id($item_id, $lang, $string, $fuzzy, $comment, $merge, $nocreate);
}

sub update_translation_props {
    my ($self, $translation_id, $props) = @_;

    #print "::update_translation_props\n" if $DEBUG;

    my $key = "translation:$translation_id";

    my $h = $self->{cache}->{$key};
    $h = $self->{cache}->{$key} = $self->SUPER::get_translation_props($translation_id) unless $h;

    return $self->SUPER::update_translation_props($translation_id, $props) if $self->_copy_props($h, $props);
}

sub get_translation_props {
    my ($self, $translation_id) = @_;

    #print "::get_translation_props\n" if $DEBUG;

    my $key = "translation:$translation_id";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};

    return $self->{cache}->{$key} = $self->SUPER::get_translation_props($translation_id);
}

sub set_translation {
    my ($self, $item_id, $lang, $string, $fuzzy, $comment, $merge) = @_;

    $string = undef if $string eq '';
    $comment = undef if $comment eq '';
    $fuzzy = $fuzzy ? 1 : 0;
    $merge = $merge ? 1 : 0;

    my $id = $self->get_translation_id($item_id, $lang, $string, $fuzzy, $comment, $merge); # create if necessary

    # if language cache was preloaded, update it as well
    my $key = "lang:$lang";
    my $h = $self->{cache}->{$key};
    if ($h) {
        $h->{$item_id} = 1;
        my $i = $self->get_item_props($item_id);
        if ($i) {
            my $s = $self->get_string_props($i->{string_id});
            $h->{generate_key($s->{string})} = 1;
            $h->{generate_key($s->{string}, $s->{context})} = 1;
        }
    }

    $self->update_translation_props($id, {
        string => $string,
        fuzzy => $fuzzy,
        comment => $comment,
        merge => $merge,
    });
}

#
#  properties
#

sub get_property_id {
    my ($self, $property, $value, $nocreate) = @_;

    my $key = "property_id:$property";

    if (exists $self->{cache}->{$key}) {
        my $id = $self->{cache}->{$key};
        return $id if $id or $nocreate;
    }

    return $self->{cache}->{$key} = $self->SUPER::get_property_id($property, $value, $nocreate);
}

sub update_property_props {
    my ($self, $property_id, $props) = @_;

    my $key = "property:$property_id";

    my $h = $self->{cache}->{$key};
    $h = $self->{cache}->{$key} = $self->SUPER::get_property_props($property_id) unless $h;

    return $self->SUPER::update_property_props($property_id, $props) if $self->_copy_props($h, $props);
}

sub get_property_props {
    my ($self, $property_id) = @_;

    my $key = "property:$property_id";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};
    return $self->{cache}->{$key} = $self->SUPER::get_property_props($property_id);
}

sub get_property {
    my ($self, $property) = @_;

    my $id = $self->get_property_id($property, undef, 1); # do not create

    if ($id) {
        my $props = $self->get_property_props($id);
        return $props->{value} if $props;
    }
    return $self->SUPER::get_property($property);
}

sub set_property {
    my ($self, $property, $value) = @_;

    my $id = $self->get_property_id($property, $value); # create if necessary

    return $self->update_property_props($id, {'value' => $value});
}

#
# Other
#

sub get_all_items_for_file {
    my ($self, $file_id) = @_;

    my $key = "all_items:$file_id";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};
    return $self->{cache}->{$key} = $self->SUPER::get_all_items_for_file($file_id);
}

sub get_file_completeness_ratio {
    my ($self, $file_id, $lang, $total) = @_;

    my $key = "completeness:$file_id:$lang:$total";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};
    return $self->{cache}->{$key} = $self->SUPER::get_file_completeness_ratio($file_id, $lang, $total);
}

sub get_all_files_for_job {
    my ($self, $namespace, $job) = @_;

    my $key = "all_files:$namespace:$job";

    return $self->{cache}->{$key} if exists $self->{cache}->{$key};
    return $self->{cache}->{$key} = $self->SUPER::get_all_files_for_job($namespace, $job);
}

sub get_translation {
    my ($self, $item_id, $lang, $allow_skip) = @_;

    my $translation_id = $self->get_translation_id($item_id, $lang, undef, undef, undef, undef, 1); # do not create

    if ($translation_id) {
        my $i = $self->get_item_props($item_id);
        my $s = $self->get_string_props($i->{string_id});

        my $props = $self->get_translation_props($translation_id);
        return if $s->{skip} and !$allow_skip;
        return ($props->{string}, $props->{fuzzy}, $props->{comment}, $props->{merge}, $s->{skip});
    }
}

#
# This builds a per-language hash of md5(string) checksums for strings that
# have a translation in the database. This hash can then be queried to determine
# if there is some translation for a particular string (no matter in which project).
# This allows expensive fuzzy matching functions [find_translation() and
# find_best_translation()] to work significantly faster.
#
sub preload_strings_for_lang {
    my ($self, $lang) = @_;

    # preload cache only once (as this may be run from different jobs
    # with different set of languages)

    my $key = "lang:$lang";

    return if exists $self->{cache}->{$key};
    my $h = $self->{cache}->{$key} = {};

    print "Preloading string cache for language '$lang'...\n";

    utf8::upgrade($lang) if defined $lang;

    my $sqlquery =
        "SELECT translations.item_id, strings.string, strings.context ".
        "FROM strings ".

        "LEFT OUTER JOIN items ".
        "ON items.string_id = strings.id ".

        "LEFT OUTER JOIN translations ".
        "ON translations.item_id = items.id ".

        "WHERE strings.skip = 0 ".
        "AND translations.language = ? ".
        "AND translations.string IS NOT NULL";

    my $sth = $self->prepare($sqlquery);
    $sth->bind_param(1, $lang) || die $sth->errstr;
    $sth->execute || die $sth->errstr;

    while (my $hr = $sth->fetchrow_hashref()) {
        $h->{$hr->{item_id}} = 1;
        $h->{generate_key($hr->{string})} = 1;
        $h->{generate_key($hr->{string}, $hr->{context})} = 1;
    }
    $sth->finish;
    $sth = undef;
}

#
# This preloads all cache data structures for the given job
#
sub preload_translations_for_job {
    my ($self, $namespace, $job, $langs) = @_;

    print "Preloading cache for job '$job' in namespace '$namespace'...\n";

    my $languages_sql = $langs ? "AND (translations.language IS NULL OR translations.language IN ('".join("','", @$langs)."')) " : "";

    my $sqlquery =
        "SELECT ".
        "files.id as file_id, files.namespace, files.job, files.path, ".
        "files.orphaned as file_orphaned, ".

        "items.id AS item_id, items.orphaned as item_orphaned, ".
        "items.hint as item_hint, items.comment AS item_comment, ".

        "strings.id as string_id, strings.string, strings.context, strings.skip, ".

        "translations.id as translation_id, translations.language, ".
        "translations.string as translation, translations.fuzzy, ".
        "translations.comment, translations.merge ".

        "FROM files ".

        "LEFT OUTER JOIN items ".
        "ON items.file_id = files.id ".

        "LEFT OUTER JOIN strings ".
        "ON strings.id = items.string_id ".

        "LEFT OUTER JOIN translations ".
        "ON translations.item_id = items.id ".
        $languages_sql.

        "WHERE files.namespace = ? ".
        "AND files.job = ?";

    my $sth = $self->prepare($sqlquery);
    $sth->bind_param(1, $namespace) || die $sth->errstr;
    $sth->bind_param(2, $job) || die $sth->errstr;
    $sth->execute || die $sth->errstr;

    while (my $hr = $sth->fetchrow_hashref()) {

        # cache 'item:<ITEM_ID>'

        my $key = 'item:'.$hr->{item_id};

        $self->{cache}->{$key} = {
            string_id => $hr->{string_id},
            hint => $hr->{item_hint},
            comment => $hr->{item_comment},
            orphaned => $hr->{item_orphaned}
        };

        if ($hr->{translation_id}) {

            # cache 'translation_id:<ITEM_ID>:<LANG>'

            $key = 'translation_id:'.$hr->{item_id}.':'.$hr->{language};
            $self->{cache}->{$key} = $hr->{translation_id};

            # cache 'translation:<TRANSLATION_ID>'

            $key = 'translation:'.$hr->{translation_id};

            $self->{cache}->{$key} = {
                string => $hr->{translation},
                fuzzy => $hr->{fuzzy},
                comment => $hr->{comment},
                merge => $hr->{merge},
                skip => $hr->{skip} # copy strings.skip flag here for easier lookup
            };
        }

        # cache 'file:<FILE_ID>'

        $key = 'file:'.$hr->{file_id};
        $self->{cache}->{$key} = {
            job => $hr->{job},
            orphaned => $hr->{file_orphaned}
        };

        # cache 'all_files:<NAMESPACE>:<JOB>'

        $key = 'all_files:'.$hr->{namespace}.':'.$hr->{job};
        my $h = (exists $self->{cache}->{$key}) ? $self->{cache}->{$key} : ($self->{cache}->{$key} = {});
        if (!exists $h->{$hr->{path}}) {
            $h->{$hr->{path}} = {
                id => $hr->{file_id},
                orphaned => $hr->{file_orphaned}
            };
        }

        # cache 'all_items:<FILE_ID>'

        if ($hr->{item_id}) {
            $key = 'all_items:'.$hr->{file_id};
            my $h = (exists $self->{cache}->{$key}) ? $self->{cache}->{$key} : ($self->{cache}->{$key} = {});
            $h->{$hr->{item_id}} = $hr->{item_orphaned};
        }

        # cache 'file_id:<HASH>'

        $key = 'file_id:'.md5(encode_utf8(join("\001", ($namespace, $job, $hr->{path}))));
        $self->{cache}->{$key} = $hr->{file_id};

        # cache 'string_id:<HASH>'

        $key = 'string_id:'.generate_key($hr->{string}, $hr->{context});
        $self->{cache}->{$key} = $hr->{string_id};

        # cache 'string:<STRING_ID>'

        $key = 'string:'.$hr->{string_id};
        $self->{cache}->{$key} = {
            string => $hr->{string},
            context => $hr->{context},
            skip => $hr->{skip}
        };

        # cache 'item_id:<FILE_ID>:<STRING_ID>'

        $key = 'item_id:'.$hr->{file_id}.':'.$hr->{string_id};
        $self->{cache}->{$key} = $hr->{item_id};
    }

    $sth->finish;
    $sth = undef;
}

sub preload_properties {
    my ($self) = @_;

    return if $self->{cache}->{properties_preloaded};

    print "Preloading properties...\n";

    my $sqlquery =
        "SELECT * ".
        "FROM properties";

    my $sth = $self->prepare($sqlquery);
    $sth->execute || die $sth->errstr;

    while (my $hr = $sth->fetchrow_hashref()) {

        # cache 'property_id:<PROPERTY>'

        my $key = 'property_id:'.$hr->{property};
        $self->{cache}->{$key} = $hr->{id};

        # cache 'property:<PROPERTY_ID>'

        $key = 'property:'.$hr->{id};

        $self->{cache}->{$key} = {
            value => $hr->{value},
        };
    }

    $sth->finish;
    $sth = undef;

    $self->{cache}->{properties_preloaded} = 1;
}

sub find_best_translation {
    my $self = shift;
    my ($namespace, $filepath, $string, $context, $lang) = @_;

    # Now that we hit the item we have no translation for, and need to query
    # the database for the best translation, preload the cache for the
    # target language (and its similar languages) if we didn't do so already
    $self->preload_strings_for_lang($lang);

    my $key = "lang:$lang";

    # if language cache was preloaded successfully, but neither string or string+context exist there, return immediately
    my $h = $self->{cache}->{$key};
    return if $h and !(exists $h->{generate_key($string)} or exists $h->{generate_key($string, $context)});

    # TODO: try to find the translation directly in the cache
    # ...

    # otherwise, find translation in the database
    return $self->SUPER::find_best_translation(@_);
}

1;
