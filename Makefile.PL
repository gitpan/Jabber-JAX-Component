#use Inline::MakeMaker;
use ExtUtils::MakeMaker;
use Cwd qw(abs_path); 
#WriteInlineMakefile(
WriteMakefile(
    clean => { 'FILES'	=> '*~ *.inl *.trc testconn core test*.txt *.tar.gz _Inline ' },
    'PREREQ_PM' => { 'Inline'	=> '0.43' },
    dist => { 'TARFLAGS'	=> 'cvf',
              'COMPRESS'        => 'gzip -9f',
    		'SUFFIX'	=> '.tgz'},
#    'LINKTYPE'	=> 'dynamic',
    'NAME'	=> 'Jabber::JAX::Component',
    'VERSION_FROM' => 'Component.pm',
    'DEFINE'	=> '',   
#    'LIBS'      => [ '-L'.abs_path('./').' '.
#		     '-L/usr/local/lib -lbedrock -ljudo -ljax '.
#		     '-lresolv -lnsl -lpthread -lresolv '.
#		     '-lnsl -lpthread' ],
#    'INC'      => '-I/usr/local/include -I'.abs_path('./'),
#    'CCFLAGS'  => '-DHAVE_CONFIG_H -D_REENTRANT '.
#	          '-D_POSIX_PTHREAD_SEMANTICS -D__USE_MALLOC',
);

