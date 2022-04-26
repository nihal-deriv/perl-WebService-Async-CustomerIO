test:
	PERL5LIB=$$PERL5LIB:/home/git/regentmarkets/perl-WebService-Async-DevExperts/local/lib/perl5 dzil test

author_test:
	PERL5LIB=$$PERL5LIB:/home/git/regentmarkets/perl-WebService-Async-DevExperts/local/lib/perl5 dzil xtest

tidy:
	find . -name '*.p?.bak' -delete
	find bin lib t -name '*.p[lm]' -o -name '*.t' | xargs perltidy -pro=/home/git/regentmarkets/cpan/rc/.perltidyrc --backup-and-modify-in-place -bext=tidyup
	find . -name '*.tidyup' -delete
