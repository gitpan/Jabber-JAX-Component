#!/bin/sh
TO=/usr/local/jax
FROM=/home/piers/code/jecl/jabber/projects
mkdir -p $TO $TO/include $TO/lib

cp $FROM/libbedrock/src/bedrock.h $TO/include/bedrock.h
cp $FROM/libbedrock/src/bedrock_callbacks.h $TO/include/bedrock_callbacks.h
cp $FROM/libbedrock/src/bedrock_debug.h $TO/include/bedrock_debug.h
cp $FROM/libjax/src/jax.h $TO/include/jax.h
cp $FROM/libjudo/src/judo.h $TO/include/judo.h
cp $FROM/libjudo/src/expat/xmlparse.h $TO/include/xmlparse.h
cp $FROM/libbedrock/src/.libs/libbedrock.a $TO/lib/libbedrock.a
cp $FROM/libjax/src/.libs/libjax.a $TO/lib/libjax.a
cp $FROM/libjudo/src/.libs/libjudo.a $TO/lib/libjudo.a

ls -lR $TO/include $TO/lib
