% Classify what verifying each megamodel declaration actually does.
%
% Verification reports every declaration as VERIFIED, but that covers different
% things. In default mode, Java, Python and Haskell checks do not run and count
% as success (ueberFFI:if/2), and succeed/1,2 accepts any file. This file asks
% Ueber's own declarations and dispatch which case applies, without changing them.
%
% Classes:
%   checked          a real check in Prolog runs
%   partly_checked   as checked, and further foreign checks are skipped
%   skipped          only foreign checks exist, so nothing runs
%   parsed_only      only succeed, but reading parses the file (term, json, xml)
%   read_only        only succeed, and reading the text file is the whole check
%   declaration      nothing to run (language, function, ...), or checked by the
%                    matching notElementOf
%
% Usage (after main.pro has loaded everything, without running verification):
%   swipl -q -f main.pro -g "['.github/ci/ueber-classify.pl'],classify('FILE'),halt" -- session
% Writes one line per declaration, in verification order: CLASS<TAB>DECLARATION

classify(File) :-
    findall(D, udeclaration(D, _), Ds),
    setup_call_cleanup(
        open(File, write, S),
        write_classes(Ds, Ds, S),
        close(S)).

% An explicit loop, because YAS defines its own forall/2 as a macro
% (languages/Ueber/macros/forall.pro), which hides the built-in one.
write_classes([], _, _).
write_classes([D|Rest], Ds, S) :-
    (   class(Ds, D, C) -> format(S, "~w\t~q~n", [C, D])
    ;   throw(error(unclassified(D), _))
    ),
    write_classes(Rest, Ds, S).

class(Ds, elementOf(F, L), declaration) :- member(notElementOf(F, L), Ds), !.
class(Ds, elementOf(_, L), C) :- !,
    findall(P, ( languageTowardsBase(L, B), member(membership(B, P, _), Ds) ), Ps),
    tests_class(L, Ps, C).
class(Ds, notElementOf(_, L), C) :- !,
    findall(P, member(membership(L, P, _), Ds), Ps),
    tests_class(L, Ps, C).
class(Ds, mapsTo(R, InFs, OutFs), C) :- !,
    ueberDispatch:overloads(Ds, R, InFs, OutFs, Os),
    findall(P, member((P, _), Os), Ps),
    tests_class(text, Ps, C).
class(_, _, declaration).

tests_class(L, Ps, C) :-
    partition_tests(Ps, Real, Foreign),
    (   Real \== [], Foreign \== [] -> C = partly_checked
    ;   Real \== [] -> C = checked
    ;   Foreign \== [] -> C = skipped
    ;   languageToBase(L, text) -> C = read_only
    ;   C = parsed_only
    ).

partition_tests([], [], []).
partition_tests([P|Ps], Real, Foreign) :-
    P =.. [Sym|_],
    partition_tests(Ps, Real0, Foreign0),
    (   Sym == succeed -> Real = Real0, Foreign = Foreign0
    ;   ueberFFI:ffi_language(Sym) -> Real = Real0, Foreign = [P|Foreign0]
    ;   Real = [P|Real0], Foreign = Foreign0
    ).
