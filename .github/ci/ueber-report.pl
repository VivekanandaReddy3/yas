% Turn the log of a verbose Ueber run (swipl -q -f main.pro -- verbose) into
% a pass/fail report: a JSON file for tools and a Markdown summary for people.
%
% Usage: swipl ueber-report.pl LOG STATUS SECONDS OUTDIR CLASSES
%   LOG      log of the verbose run (stdout and stderr)
%   STATUS   exit status of that run
%   SECONDS  duration of that run
%   OUTDIR   where ueber-report.json and ueber-report.md are written
%   CLASSES  output of ueber-classify.pl: what each check actually does
% Exits with 0 if the run passed and 1 otherwise.
%
% The run fails if swipl exited non-zero, if an error was reported, if the
% final directive of main.pro failed, if Ueber listed megamodel problems, if a
% relationship is not OK or not VERIFIED, or if a phase or the summary is
% missing. (The exit status alone is not enough: when the final directive
% fails, swipl reads end-of-file at its toplevel and exits with 0.)
%
% Written for SWI-Prolog 7.6 and later; CI runs it on every version it tests.

% library(http/json) became library(json) in SWI-Prolog 10.
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, [Log, StatusA, SecondsA, OutDir, ClassFile|_]),
    atom_number(StatusA, Status),
    atom_number(SecondsA, Seconds),
    read_lines(Log, Lines),
    read_classes(ClassFile, Classes),
    analyse(Lines, Classes, Status, Seconds, Report),
    directory_file_path(OutDir, 'ueber-report.json', JsonFile),
    directory_file_path(OutDir, 'ueber-report.md', MdFile),
    setup_call_cleanup(open(JsonFile, write, J),
                       ( json_write_dict(J, Report), nl(J) ), close(J)),
    setup_call_cleanup(open(MdFile, write, M), markdown(M, Report), close(M)),
    markdown(user_output, Report),
    ( Report.result == "PASS" -> halt(0) ; halt(1) ).

read_lines(File, Lines) :-
    setup_call_cleanup(open(File, read, S), read_lines_(S, Lines), close(S)).
read_lines_(S, Lines) :-
    read_line_to_string(S, L),
    ( L == end_of_file -> Lines = [] ; Lines = [L|Ls], read_lines_(S, Ls) ).

% CLASS<TAB>DIRECTORY<TAB>DECLARATION lines
read_classes(File, Classes) :-
    (   exists_file(File) -> read_lines(File, Lines) ; Lines = [] ),
    maplist(class_line, Lines, Classes).

class_line(L, D-C) :-
    split_string(L, "\t", "", [C, _Dir|Parts]),
    atomic_list_concat(Parts, '\t', A),
    atom_string(A, D).

% Assign each line to the section it occurs in.
sections([], _, []).
sections([L|Ls], Sec0, Out) :-
    ( section_header(L, Sec) -> Out = Out1 ; Sec = Sec0, Out = [Sec-L|Out1] ),
    sections(Ls, Sec, Out1).

section_header("Megamodel processing:", processing).
section_header("Megamodel well-formedness:", wellformedness).
section_header("Megamodel verification:", verification).
section_header("Megamodel problems:", problems).

% " * Declaration: Status" with Status as printed by languages/Ueber/ueberMain.pro
result_line(L, Decl, Status) :-
    string_concat(" * ", Rest, L),
    member(Status, ["OK", "VERIFIED", "FAIL"]),
    string_concat(": ", Status, Suffix),
    string_concat(Decl, Suffix, Rest), !.

% The relationship kind is the functor name, e.g., elementOf, mapsTo.
kind(Decl, Kind) :-
    ( sub_string(Decl, B, _, _, "(") -> sub_string(Decl, 0, B, _, Kind) ; Kind = Decl ).

phase(Tagged, Phase, Results, Unparsed) :-
    findall(L, member(Phase-L, Tagged), Ls),
    findall(D-S, (member(L, Ls), result_line(L, D, S)), Results),
    findall(L, (member(L, Ls), L \== "", \+ result_line(L, _, _)), Unparsed).

% A " * Declaration: " line without a status: the check that was running
% when the run stopped (e.g., an uncaught exception).
stopped_at(Tagged, Phase, Decl) :-
    member(Phase-L, Tagged),
    string_concat(" * ", Rest, L),
    string_concat(Decl, ": ", Rest), !.

summary_count(Lines, Name, N) :-
    string_concat(" ", Name, Tail0), string_concat(Tail0, ".", Tail),
    ( member(L, Lines), string_concat(NS, Tail, L), number_string(N, NS) -> true ; N = null ).

errors(Lines, Errors) :-
    findall(E, ( nth1(I, Lines, L), string_concat("ERROR", _, L),
                 J is I + 1,
                 ( nth1(J, Lines, Next), string_concat("ERROR:    ", _, Next)
                 -> atomics_to_string([L, " ", Next], E) ; E = L ) ),
            Es0),
    exclude(continuation, Es0, Errors).
continuation(E) :- string_concat("ERROR:    ", _, E).

% Combine run results and classes, check by check, in verification order.
% Passed checks count under their class; the classes must match the run.
assurance(VR, Classes, Dict, Matches) :-
    walk(VR, Classes, Passed, Failed, Left, Matches),
    count(Passed, "checked", Checked),
    count(Passed, "partly_checked", Partly),
    count(Passed, "skipped", Skipped),
    count(Passed, "loaded", Loaded),
    count(Passed, "parsed_only", Parsed),
    count(Passed, "read_only", Read),
    count(Passed, "declaration", Decl),
    length(Left, NotRun),
    length(Classes, Total),
    Dict = _{ checked: Checked, partly_checked: Partly, skipped: Skipped,
              loaded: Loaded, parsed_only: Parsed, read_only: Read, declaration: Decl,
              failed: Failed, not_run: NotRun, total: Total }.

walk([], Left, [], 0, Left, true).
walk([_|_], [], [], 0, [], false).
walk([D1-S|Rs], [D2-C|Cs], Passed, Failed, Left, Matches) :-
    (   D1 == D2 -> M = true ; M = false ),
    walk(Rs, Cs, Passed0, Failed0, Left, Matches0),
    (   S == "FAIL" -> Passed = Passed0, Failed is Failed0 + 1
    ;   Passed = [C|Passed0], Failed = Failed0 ),
    (   M == true -> Matches = Matches0 ; Matches = false ).

count(List, X, N) :- aggregate_all(count, member(X, List), N).

analyse(Lines, Classes, Status, Seconds, Report) :-
    sections(Lines, none, Tagged),
    phase(Tagged, wellformedness, WF, WFUnparsed),
    phase(Tagged, verification, VR, VRUnparsed),
    findall(P, ( member(problems-L, Tagged), string_concat(" * ", P, L) ), Problems),
    errors(Lines, Errors),
    ( member(L, Lines), sub_string(L, _, _, _, "Goal (directive) failed") -> DirFailed = true ; DirFailed = false ),
    maplist(summary_count(Lines), ["languages", "files", "membership tests", "functions", "function applications"],
            [NLang, NFiles, NMember, NFun, NApp]),
    phase_dict(WF, "OK", WFDict),
    phase_dict(VR, "VERIFIED", VRDict),
    findall(_{phase:"well-formedness", relationship:D}, member(D-"FAIL", WF), F1),
    findall(_{phase:"verification", relationship:D}, member(D-"FAIL", VR), F2),
    append(F1, F2, Failures),
    by_kind(WF, VR, Kinds),
    assurance(VR, Classes, Assurance, ClassesMatch),
    findall(D, member(D-_, VR), VDs), sort(VDs, DistinctDs), length(DistinctDs, Distinct),
    ( ( stopped_at(Tagged, wellformedness, SD) -> StopPhase = "well-formedness"
      ; stopped_at(Tagged, verification, SD) -> StopPhase = "verification" )
    -> Stopped = _{phase: StopPhase, relationship: SD}
    ;  Stopped = null ),
    reasons(Status, Errors, DirFailed, Problems, Failures, WF, VR, NApp, Stopped, ClassesMatch, Classes, Reasons0),
    length(WF, NWF), length(VR, NVR),
    ( VR \== [], NVR < NWF
    -> format(string(Incomplete), "verification incomplete: ~w of ~w relationships checked", [NVR, NWF]),
       append(Reasons0, [Incomplete], Reasons)
    ;  Reasons = Reasons0 ),
    ( Reasons == [] -> Result = "PASS" ; Result = "FAIL" ),
    current_prolog_flag(version, V),
    Major is V // 10000, Minor is (V // 100) mod 100, Patch is V mod 100,
    format(string(SWI), "~w.~w.~w", [Major, Minor, Patch]),
    ( getenv('GITHUB_SHA', Sha) -> atom_string(Sha, Commit) ; Commit = null ),
    append(WFUnparsed, VRUnparsed, Unparsed),
    Report = _{ result: Result,
                reasons: Reasons,
                swipl: SWI,
                commit: Commit,
                exit_status: Status,
                seconds: Seconds,
                collected: _{ languages: NLang, files: NFiles, membership_tests: NMember,
                              functions: NFun, function_applications: NApp },
                distinct_relationships: Distinct,
                assurance: Assurance,
                wellformedness: WFDict,
                verification: VRDict,
                by_kind: Kinds,
                failures: Failures,
                problems: Problems,
                errors: Errors,
                directive_failed: DirFailed,
                stopped_at: Stopped,
                unparsed_lines: Unparsed }.

phase_dict(Results, Pass, _{checked: N, passed: P, failed: F}) :-
    length(Results, N),
    aggregate_all(count, member(_-Pass, Results), P),
    aggregate_all(count, member(_-"FAIL", Results), F).

by_kind(WF, VR, Kinds) :-
    findall(K, (member(D-_, WF), kind(D, K)), Ks0),
    sort(Ks0, Ks),
    findall(_{kind: K, relationships: N, failed: F},
            ( member(K, Ks),
              aggregate_all(count, (member(D-_, WF), kind(D, K)), N),
              aggregate_all(count, ( ( member(D-"FAIL", WF) ; member(D-"FAIL", VR) ), kind(D, K) ), F) ),
            Kinds).

reasons(Status, Errors, DirFailed, Problems, Failures, WF, VR, NApp, Stopped, ClassesMatch, Classes, Reasons) :-
    findall(R,
      ( Status =\= 0, format(string(R), "swipl exited with status ~w", [Status])
      ; Stopped \== null,
        format(string(R), "run stopped during ~w at ~w", [Stopped.phase, Stopped.relationship])
      ; Errors \== [], length(Errors, N), format(string(R), "~w error(s) reported", [N])
      ; DirFailed == true, R = "a directive in main.pro failed; verification did not complete"
      ; Problems \== [], length(Problems, N), format(string(R), "~w megamodel problem(s)", [N])
      ; Failures \== [], length(Failures, N), format(string(R), "~w relationship check(s) failed", [N])
      ; WF == [], R = "no well-formedness results"
      ; VR == [], R = "no verification results"
      ; NApp == null, R = "summary missing; collection did not complete"
      ; Classes == [], R = "no classification of the checks"
      ; ClassesMatch == false, R = "classification does not match the run"
      ), Reasons).

% Markdown summary (also printed to the console)
markdown(S, R) :-
    format(S, "## Ueber verification: ~w~n~n", [R.result]),
    format(S, "SWI-Prolog ~w", [R.swipl]),
    ( R.commit == null -> true ; sub_atom(R.commit, 0, 7, _, Short), format(S, " · commit `~w`", [Short]) ),
    format(S, " · ~w s~n~n", [R.seconds]),
    forall(member(Reason, R.reasons), format(S, "- **~w**~n", [Reason])),
    ( R.reasons == [] -> true ; nl(S) ),
    C = R.collected,
    format(S, "| Languages | Files | Functions | Function applications |~n|---:|---:|---:|---:|~n", []),
    format(S, "| ~w | ~w | ~w | ~w |~n~n", [C.languages, C.files, C.functions, C.function_applications]),
    format(S, "| Phase | Checked | Passed | Failed |~n|---|---:|---:|---:|~n", []),
    W = R.wellformedness, V = R.verification,
    format(S, "| Well-formedness | ~w | ~w | ~w |~n", [W.checked, W.passed, W.failed]),
    format(S, "| Verification | ~w | ~w | ~w |~n~n", [V.checked, V.passed, V.failed]),
    As = R.assurance,
    format(S, "### What the ~w checks actually did~n~n", [As.total]),
    format(S, "| Result | Checks |~n|---|---:|~n", []),
    format(S, "| Really checked | ~w |~n", [As.checked]),
    format(S, "| Really checked, some foreign checks skipped | ~w |~n", [As.partly_checked]),
    format(S, "| Skipped: foreign (Java, Python, Haskell) checks only, nothing ran | ~w |~n", [As.skipped]),
    format(S, "| Prolog source loaded, nothing else checked | ~w |~n", [As.loaded]),
    format(S, "| File parsed, nothing else checked | ~w |~n", [As.parsed_only]),
    format(S, "| File read, nothing else checked | ~w |~n", [As.read_only]),
    format(S, "| Declaration only, nothing to run | ~w |~n", [As.declaration]),
    format(S, "| Failed | ~w |~n", [As.failed]),
    format(S, "| Not reached | ~w |~n~n", [As.not_run]),
    format(S, "Distinct relationships: ~w (checks include repeats).~n~n", [R.distinct_relationships]),
    format(S, "<details><summary>Relationships by kind</summary>~n~n| Kind | Relationships | Failed |~n|---|---:|---:|~n", []),
    forall(member(K, R.by_kind), format(S, "| `~w` | ~w | ~w |~n", [K.kind, K.relationships, K.failed])),
    format(S, "~n</details>~n~n", []),
    list_section(S, "Failed relationships", R.failures, failure),
    list_section(S, "Megamodel problems", R.problems, plain),
    list_section(S, "Errors", R.errors, plain),
    list_section(S, "Unparsed lines in the result sections", R.unparsed_lines, plain).

list_section(_, _, [], _) :- !.
list_section(S, Title, Items, Kind) :-
    length(Items, N),
    format(S, "### ~w (~w)~n~n", [Title, N]),
    ( length(Show, 50), append(Show, _, Items) -> true ; Show = Items ),
    forall(member(I, Show), item(S, Kind, I)),
    ( N > 50 -> More is N - 50, format(S, "- ... and ~w more (see ueber-report.json)~n", [More]) ; true ),
    nl(S).

item(S, failure, I) :- !, format(S, "- ~w: `~w`~n", [I.phase, I.relationship]).
item(S, plain, I) :- format(S, "- `~w`~n", [I]).
