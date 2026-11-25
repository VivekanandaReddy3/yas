# Generated from Fsml.g4 by ANTLR 4.5.3
from antlr4 import *
if __name__ is not None and "." in __name__:
    from .FsmlParser import FsmlParser
else:
    from FsmlParser import FsmlParser
from FsmlModel import Fsm

# This class defines a complete listener for a parse tree produced by FsmlParser.
class FsmlListener(ParseTreeListener):

    # Enter a parse tree produced by FsmlParser#fsm.
    def enterFsm(self, ctx:FsmlParser.FsmContext):
        pass

    # Exit a parse tree produced by FsmlParser#fsm.
    def exitFsm(self, ctx:FsmlParser.FsmContext):
        pass


    # Enter a parse tree produced by FsmlParser#statedecl.
    def enterStatedecl(self, ctx:FsmlParser.StatedeclContext):
        pass

    # Exit a parse tree produced by FsmlParser#statedecl.
    def exitStatedecl(self, ctx:FsmlParser.StatedeclContext):
        pass


    # Enter a parse tree produced by FsmlParser#transition.
    def enterTransition(self, ctx:FsmlParser.TransitionContext):
        pass

    # Exit a parse tree produced by FsmlParser#transition.
    def exitTransition(self, ctx:FsmlParser.TransitionContext):
        pass


    # Enter a parse tree produced by FsmlParser#stateid.
    def enterStateid(self, ctx:FsmlParser.StateidContext):
        pass

    # Exit a parse tree produced by FsmlParser#stateid.
    def exitStateid(self, ctx:FsmlParser.StateidContext):
        pass


    # Enter a parse tree produced by FsmlParser#event.
    def enterEvent(self, ctx:FsmlParser.EventContext):
        pass

    # Exit a parse tree produced by FsmlParser#event.
    def exitEvent(self, ctx:FsmlParser.EventContext):
        pass


    # Enter a parse tree produced by FsmlParser#action.
    def enterAction(self, ctx:FsmlParser.ActionContext):
        pass

    # Exit a parse tree produced by FsmlParser#action.
    def exitAction(self, ctx:FsmlParser.ActionContext):
        pass


