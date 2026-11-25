# Generated from Fsml.g4 by ANTLR 4.5.3
from antlr4 import *
from io import StringIO

from FsmlModel import Fsm

def serializedATN():
    with StringIO() as buf:
        buf.write("\3\u0430\ud6d1\u8206\uad2d\u4417\uaef1\u8d80\uaadd\2\13")
        buf.write(":\b\1\4\2\t\2\4\3\t\3\4\4\t\4\4\5\t\5\4\6\t\6\4\7\t\7")
        buf.write("\4\b\t\b\4\t\t\t\4\n\t\n\3\2\3\2\3\2\3\2\3\2\3\2\3\2\3")
        buf.write("\2\3\3\3\3\3\3\3\3\3\3\3\3\3\4\3\4\3\5\3\5\3\6\3\6\3\7")
        buf.write("\3\7\3\7\3\b\3\b\3\t\6\t\60\n\t\r\t\16\t\61\3\n\6\n\65")
        buf.write("\n\n\r\n\16\n\66\3\n\3\n\2\2\13\3\3\5\4\7\5\t\6\13\7\r")
        buf.write("\b\17\t\21\n\23\13\3\2\4\4\2C\\c|\5\2\13\f\17\17\"\";")
        buf.write("\2\3\3\2\2\2\2\5\3\2\2\2\2\7\3\2\2\2\2\t\3\2\2\2\2\13")
        buf.write("\3\2\2\2\2\r\3\2\2\2\2\17\3\2\2\2\2\21\3\2\2\2\2\23\3")
        buf.write("\2\2\2\3\25\3\2\2\2\5\35\3\2\2\2\7#\3\2\2\2\t%\3\2\2\2")
        buf.write("\13\'\3\2\2\2\r)\3\2\2\2\17,\3\2\2\2\21/\3\2\2\2\23\64")
        buf.write("\3\2\2\2\25\26\7k\2\2\26\27\7p\2\2\27\30\7k\2\2\30\31")
        buf.write("\7v\2\2\31\32\7k\2\2\32\33\7c\2\2\33\34\7n\2\2\34\4\3")
        buf.write("\2\2\2\35\36\7u\2\2\36\37\7v\2\2\37 \7c\2\2 !\7v\2\2!")
        buf.write("\"\7g\2\2\"\6\3\2\2\2#$\7}\2\2$\b\3\2\2\2%&\7\177\2\2")
        buf.write("&\n\3\2\2\2\'(\7\61\2\2(\f\3\2\2\2)*\7/\2\2*+\7@\2\2+")
        buf.write("\16\3\2\2\2,-\7=\2\2-\20\3\2\2\2.\60\t\2\2\2/.\3\2\2\2")
        buf.write("\60\61\3\2\2\2\61/\3\2\2\2\61\62\3\2\2\2\62\22\3\2\2\2")
        buf.write("\63\65\t\3\2\2\64\63\3\2\2\2\65\66\3\2\2\2\66\64\3\2\2")
        buf.write("\2\66\67\3\2\2\2\678\3\2\2\289\b\n\2\29\24\3\2\2\2\5\2")
        buf.write("\61\66\3\b\2\2")
        return buf.getvalue()


class FsmlLexer(Lexer):

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]


    T__0 = 1
    T__1 = 2
    T__2 = 3
    T__3 = 4
    T__4 = 5
    T__5 = 6
    T__6 = 7
    NAME = 8
    WS = 9

    modeNames = [ "DEFAULT_MODE" ]

    literalNames = [ "<INVALID>",
            "'initial'", "'state'", "'{'", "'}'", "'/'", "'->'", "';'" ]

    symbolicNames = [ "<INVALID>",
            "NAME", "WS" ]

    ruleNames = [ "T__0", "T__1", "T__2", "T__3", "T__4", "T__5", "T__6", 
                  "NAME", "WS" ]

    grammarFileName = "Fsml.g4"

    def __init__(self, input=None):
        super().__init__(input)
        self.checkVersion("4.5.3")
        self._interp = LexerATNSimulator(self, self.atn, self.decisionsToDFA, PredictionContextCache())
        self._actions = None
        self._predicates = None


