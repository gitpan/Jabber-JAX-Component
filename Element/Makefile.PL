#use Inline::MakeMaker;
use ExtUtils::MakeMaker;
use Cwd qw(abs_path); 
#WriteInlineMakefile(
WriteMakefile(
    clean => { 'FILES'	=> '*~ *.inl *.trc testconn core test*.txt *.tar.gz _Inline ' },
    'PREREQ_PM' => { 'Inline'	=> '0.43' },
    'LINKTYPE'	=> 'dynamic',
    'NAME'	=> 'Jabber::Judo::Element',
    'VERSION_FROM' => 'Element.pm',
    'DEFINE'	=> '',   
    'LIBS'      => [ '-L'.abs_path('./').' '.
                     '-L'.abs_path('../').' '.
		     '-L/usr/local/lib -lbedrock -ljudo -ljax '.
		     '-lresolv -lnsl -lpthread -lresolv '.
		     '-lnsl -lpthread' ],
    'INC'      => '-I/usr/local/include -I'.abs_path('./').' '.
                  '-I/usr/local/include -I'.abs_path('../'),
    'CCFLAGS'  => '-DHAVE_CONFIG_H -D_REENTRANT '.
	          '-D_POSIX_PTHREAD_SEMANTICS -D__USE_MALLOC',
);

