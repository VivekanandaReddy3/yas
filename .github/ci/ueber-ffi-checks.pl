% List the foreign (Java, Python, Haskell) implementations that Ueber's
% declarations call, so that ueber-verify-ffi.sh builds exactly those instead
% of keeping its own list.
%
% Foreign implementations appear in membership/3 (acceptors and checkers) and
% function/5 (functions), e.g.
%   membership(fsml(text), java('org.softlang.fsml.FsmlAcceptor'), [.])
% Ueber resolves the last argument to the declaring directory.
%
% Usage (after main.pro has loaded everything, without running verification):
%   swipl -q -f main.pro -g "['.github/ci/ueber-ffi-checks.pl'],ffi_checks('FILE'),halt" -- session
% Writes one line per distinct implementation, sorted (stdout is taken by
% Ueber's own processing output):
%   LANGUAGE<TAB>DIRECTORY<TAB>NAME
% e.g.  java<TAB>languages/FSML/Java/.<TAB>org.softlang.fsml.FsmlAcceptor

ffi_checks(File) :-
    findall(Lang-Dir-Name, foreign(Lang, Dir, Name), Found),
    sort(Found, Sorted),
    setup_call_cleanup(open(File, write, S), print_checks(Sorted, S), close(S)).

% An explicit loop, because YAS defines its own forall/2 as a macro
% (languages/Ueber/macros/forall.pro), which hides the built-in one.
print_checks([], _).
print_checks([Lang-Dir-Name|Rest], S) :-
    format(S, "~w\t~w\t~w~n", [Lang, Dir, Name]),
    print_checks(Rest, S).

foreign(Lang, Dir, Name) :-
    udeclaration(D, _),
    implementation(D, P, [Dir|_]),
    P =.. [Lang, Name],
    ueberFFI:ffi_language(Lang).

implementation(membership(_, P, Args), P, Args).
implementation(function(_, _, _, P, Args), P, Args).
