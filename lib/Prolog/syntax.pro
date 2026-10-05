:- op(899, xfx, (&)).
:- op(900, xfx, (=>)).
:- op(900, xfx, (~>)).
:- op(500, fx, (#)).
% Newer SWI-Prolog versions declare table as a prefix operator (tabling;
% absent in 7.6.4, present in 7.7.25 and later);
% YAS uses table as a plain atom (e.g., DDL) and does not use tabling.
:- op(0, fx, table).

