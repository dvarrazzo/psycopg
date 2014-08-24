"""Python exceptions for every PostgreSQL error code and error class
"""

# Copyright (C) 2014 Daniele Varrazzo  <daniele.varrazzo@gmail.com>
#
# psycopg2 is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# psycopg2 is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.

import psycopg2
from psycopg2 import _psycopg as imp


def lookup(code, _cache={}):
    """Lookup an error code or class code and return its exception.

    Raise `KeyError` if the code is not found.
    """
    if _cache:
        return _cache[code]

    # Generate the lookup map at first use.
    for o in globals().itervalues():
        if isinstance(o, type) and issubclass(o, psycopg2.Error):
            _cache[o.pgcode] = o

    return lookup(code)


# autogenerated data: do not edit below this point.


# Exceptions representing PostgreSQL error classes

class ClassSuccessfulCompletion(psycopg2.DatabaseError):
    pgcode = '00'

class ClassWarning(psycopg2.DatabaseError):
    pgcode = '01'

class ClassNoData(psycopg2.DatabaseError):
    pgcode = '02'

class ClassSqlStatementNotYetComplete(psycopg2.DatabaseError):
    pgcode = '03'

class ClassConnectionException(psycopg2.DatabaseError):
    pgcode = '08'

class ClassTriggeredActionException(psycopg2.DatabaseError):
    pgcode = '09'

class ClassFeatureNotSupported(psycopg2.DatabaseError):
    pgcode = '0A'

class ClassInvalidTransactionInitiation(psycopg2.DatabaseError):
    pgcode = '0B'

class ClassLocatorException(psycopg2.DatabaseError):
    pgcode = '0F'

class ClassInvalidGrantor(psycopg2.DatabaseError):
    pgcode = '0L'

class ClassInvalidRoleSpecification(psycopg2.DatabaseError):
    pgcode = '0P'

class ClassDiagnosticsException(psycopg2.DatabaseError):
    pgcode = '0Z'

class ClassCaseNotFound(psycopg2.DatabaseError):
    pgcode = '20'

class ClassCardinalityViolation(psycopg2.DatabaseError):
    pgcode = '21'

class ClassDataException(psycopg2.DatabaseError):
    pgcode = '22'

class ClassIntegrityConstraintViolation(psycopg2.DatabaseError):
    pgcode = '23'

class ClassInvalidCursorState(psycopg2.DatabaseError):
    pgcode = '24'

class ClassInvalidTransactionState(psycopg2.DatabaseError):
    pgcode = '25'

class ClassInvalidSqlStatementName(psycopg2.DatabaseError):
    pgcode = '26'

class ClassTriggeredDataChangeViolation(psycopg2.DatabaseError):
    pgcode = '27'

class ClassInvalidAuthorizationSpecification(psycopg2.DatabaseError):
    pgcode = '28'

class ClassDependentPrivilegeDescriptorsStillExist(psycopg2.DatabaseError):
    pgcode = '2B'

class ClassInvalidTransactionTermination(psycopg2.DatabaseError):
    pgcode = '2D'

class ClassSqlRoutineException(psycopg2.DatabaseError):
    pgcode = '2F'

class ClassInvalidCursorName(psycopg2.DatabaseError):
    pgcode = '34'

class ClassExternalRoutineException(psycopg2.DatabaseError):
    pgcode = '38'

class ClassExternalRoutineInvocationException(psycopg2.DatabaseError):
    pgcode = '39'

class ClassSavepointException(psycopg2.DatabaseError):
    pgcode = '3B'

class ClassInvalidCatalogName(psycopg2.DatabaseError):
    pgcode = '3D'

class ClassInvalidSchemaName(psycopg2.DatabaseError):
    pgcode = '3F'

class ClassTransactionRollback(psycopg2.DatabaseError):
    pgcode = '40'

class ClassSyntaxErrorOrAccessRuleViolation(psycopg2.DatabaseError):
    pgcode = '42'

class ClassWithCheckOptionViolation(psycopg2.DatabaseError):
    pgcode = '44'

class ClassInsufficientResources(psycopg2.DatabaseError):
    pgcode = '53'

class ClassProgramLimitExceeded(psycopg2.DatabaseError):
    pgcode = '54'

class ClassObjectNotInPrerequisiteState(psycopg2.DatabaseError):
    pgcode = '55'

class ClassOperatorIntervention(psycopg2.DatabaseError):
    pgcode = '57'

class ClassSystemError(psycopg2.DatabaseError):
    pgcode = '58'

class ClassConfigurationFileError(psycopg2.DatabaseError):
    pgcode = 'F0'

class ClassForeignDataWrapperError(psycopg2.DatabaseError):
    pgcode = 'HV'

class ClassPlPgsqlError(psycopg2.DatabaseError):
    pgcode = 'P0'

class ClassInternalError(psycopg2.DatabaseError):
    pgcode = 'XX'


# Exceptions representing PostgreSQL errors

class SuccessfulCompletion(ClassSuccessfulCompletion, imp.DatabaseError):
    pgcode = '00000'

class Warning(ClassWarning, imp.DatabaseError):
    pgcode = '01000'

class NullValueEliminatedInSetFunction(ClassWarning, imp.DatabaseError):
    pgcode = '01003'

class PrivilegeNotRevoked(ClassWarning, imp.DatabaseError):
    pgcode = '01006'

class PrivilegeNotGranted(ClassWarning, imp.DatabaseError):
    pgcode = '01007'

class ImplicitZeroBitPadding(ClassWarning, imp.DatabaseError):
    pgcode = '01008'

class DynamicResultSetsReturned(ClassWarning, imp.DatabaseError):
    pgcode = '0100C'

class DeprecatedFeature(ClassWarning, imp.DatabaseError):
    pgcode = '01P01'

class NoData(ClassNoData, imp.DatabaseError):
    pgcode = '02000'

class NoAdditionalDynamicResultSetsReturned(ClassNoData, imp.DatabaseError):
    pgcode = '02001'

class SqlStatementNotYetComplete(ClassSqlStatementNotYetComplete, imp.DatabaseError):
    pgcode = '03000'

class ConnectionException(ClassConnectionException, imp.DatabaseError):
    pgcode = '08000'

class SqlclientUnableToEstablishSqlconnection(ClassConnectionException, imp.DatabaseError):
    pgcode = '08001'

class ConnectionDoesNotExist(ClassConnectionException, imp.DatabaseError):
    pgcode = '08003'

class SqlserverRejectedEstablishmentOfSqlconnection(ClassConnectionException, imp.DatabaseError):
    pgcode = '08004'

class ConnectionFailure(ClassConnectionException, imp.DatabaseError):
    pgcode = '08006'

class TransactionResolutionUnknown(ClassConnectionException, imp.DatabaseError):
    pgcode = '08007'

class ProtocolViolation(ClassConnectionException, imp.DatabaseError):
    pgcode = '08P01'

class TriggeredActionException(ClassTriggeredActionException, imp.DatabaseError):
    pgcode = '09000'

class FeatureNotSupported(ClassFeatureNotSupported, imp.NotSupportedError):
    pgcode = '0A000'

class InvalidTransactionInitiation(ClassInvalidTransactionInitiation, imp.DatabaseError):
    pgcode = '0B000'

class LocatorException(ClassLocatorException, imp.DatabaseError):
    pgcode = '0F000'

class InvalidLocatorSpecification(ClassLocatorException, imp.DatabaseError):
    pgcode = '0F001'

class InvalidGrantor(ClassInvalidGrantor, imp.DatabaseError):
    pgcode = '0L000'

class InvalidGrantOperation(ClassInvalidGrantor, imp.DatabaseError):
    pgcode = '0LP01'

class InvalidRoleSpecification(ClassInvalidRoleSpecification, imp.DatabaseError):
    pgcode = '0P000'

class DiagnosticsException(ClassDiagnosticsException, imp.DatabaseError):
    pgcode = '0Z000'

class StackedDiagnosticsAccessedWithoutActiveHandler(ClassDiagnosticsException, imp.DatabaseError):
    pgcode = '0Z002'

class CaseNotFound(ClassCaseNotFound, imp.ProgrammingError):
    pgcode = '20000'

class CardinalityViolation(ClassCardinalityViolation, imp.ProgrammingError):
    pgcode = '21000'

class DataException(ClassDataException, imp.DataError):
    pgcode = '22000'

class StringDataRightTruncation(ClassDataException, imp.DataError):
    pgcode = '22001'

class NullValueNoIndicatorParameter(ClassDataException, imp.DataError):
    pgcode = '22002'

class NumericValueOutOfRange(ClassDataException, imp.DataError):
    pgcode = '22003'

class ErrorInAssignment(ClassDataException, imp.DataError):
    pgcode = '22005'

class InvalidDatetimeFormat(ClassDataException, imp.DataError):
    pgcode = '22007'

class DatetimeFieldOverflow(ClassDataException, imp.DataError):
    pgcode = '22008'

class InvalidTimeZoneDisplacementValue(ClassDataException, imp.DataError):
    pgcode = '22009'

class EscapeCharacterConflict(ClassDataException, imp.DataError):
    pgcode = '2200B'

class InvalidUseOfEscapeCharacter(ClassDataException, imp.DataError):
    pgcode = '2200C'

class InvalidEscapeOctet(ClassDataException, imp.DataError):
    pgcode = '2200D'

class ZeroLengthCharacterString(ClassDataException, imp.DataError):
    pgcode = '2200F'

class MostSpecificTypeMismatch(ClassDataException, imp.DataError):
    pgcode = '2200G'

class NotAnXmlDocument(ClassDataException, imp.DataError):
    pgcode = '2200L'

class InvalidXmlDocument(ClassDataException, imp.DataError):
    pgcode = '2200M'

class InvalidXmlContent(ClassDataException, imp.DataError):
    pgcode = '2200N'

class InvalidXmlComment(ClassDataException, imp.DataError):
    pgcode = '2200S'

class InvalidXmlProcessingInstruction(ClassDataException, imp.DataError):
    pgcode = '2200T'

class InvalidIndicatorParameterValue(ClassDataException, imp.DataError):
    pgcode = '22010'

class SubstringError(ClassDataException, imp.DataError):
    pgcode = '22011'

class DivisionByZero(ClassDataException, imp.DataError):
    pgcode = '22012'

class InvalidArgumentForNtileFunction(ClassDataException, imp.DataError):
    pgcode = '22014'

class IntervalFieldOverflow(ClassDataException, imp.DataError):
    pgcode = '22015'

class InvalidArgumentForNthValueFunction(ClassDataException, imp.DataError):
    pgcode = '22016'

class InvalidCharacterValueForCast(ClassDataException, imp.DataError):
    pgcode = '22018'

class InvalidEscapeCharacter(ClassDataException, imp.DataError):
    pgcode = '22019'

class InvalidRegularExpression(ClassDataException, imp.DataError):
    pgcode = '2201B'

class InvalidArgumentForLogarithm(ClassDataException, imp.DataError):
    pgcode = '2201E'

class InvalidArgumentForPowerFunction(ClassDataException, imp.DataError):
    pgcode = '2201F'

class InvalidArgumentForWidthBucketFunction(ClassDataException, imp.DataError):
    pgcode = '2201G'

class InvalidRowCountInLimitClause(ClassDataException, imp.DataError):
    pgcode = '2201W'

class InvalidRowCountInResultOffsetClause(ClassDataException, imp.DataError):
    pgcode = '2201X'

class InvalidLimitValue(ClassDataException, imp.DataError):
    pgcode = '22020'

class CharacterNotInRepertoire(ClassDataException, imp.DataError):
    pgcode = '22021'

class IndicatorOverflow(ClassDataException, imp.DataError):
    pgcode = '22022'

class InvalidParameterValue(ClassDataException, imp.DataError):
    pgcode = '22023'

class UnterminatedCString(ClassDataException, imp.DataError):
    pgcode = '22024'

class InvalidEscapeSequence(ClassDataException, imp.DataError):
    pgcode = '22025'

class StringDataLengthMismatch(ClassDataException, imp.DataError):
    pgcode = '22026'

class TrimError(ClassDataException, imp.DataError):
    pgcode = '22027'

class ArraySubscriptError(ClassDataException, imp.DataError):
    pgcode = '2202E'

class FloatingPointException(ClassDataException, imp.DataError):
    pgcode = '22P01'

class InvalidTextRepresentation(ClassDataException, imp.DataError):
    pgcode = '22P02'

class InvalidBinaryRepresentation(ClassDataException, imp.DataError):
    pgcode = '22P03'

class BadCopyFileFormat(ClassDataException, imp.DataError):
    pgcode = '22P04'

class UntranslatableCharacter(ClassDataException, imp.DataError):
    pgcode = '22P05'

class NonstandardUseOfEscapeCharacter(ClassDataException, imp.DataError):
    pgcode = '22P06'

class IntegrityConstraintViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23000'

class RestrictViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23001'

class NotNullViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23502'

class ForeignKeyViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23503'

class UniqueViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23505'

class CheckViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23514'

class ExclusionViolation(ClassIntegrityConstraintViolation, imp.IntegrityError):
    pgcode = '23P01'

class InvalidCursorState(ClassInvalidCursorState, imp.InternalError):
    pgcode = '24000'

class InvalidTransactionState(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25000'

class ActiveSqlTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25001'

class BranchTransactionAlreadyActive(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25002'

class InappropriateAccessModeForBranchTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25003'

class InappropriateIsolationLevelForBranchTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25004'

class NoActiveSqlTransactionForBranchTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25005'

class ReadOnlySqlTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25006'

class SchemaAndDataStatementMixingNotSupported(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25007'

class HeldCursorRequiresSameIsolationLevel(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25008'

class NoActiveSqlTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25P01'

class InFailedSqlTransaction(ClassInvalidTransactionState, imp.InternalError):
    pgcode = '25P02'

class InvalidSqlStatementName(ClassInvalidSqlStatementName, imp.OperationalError):
    pgcode = '26000'

UndefinedPstatement = InvalidSqlStatementName

class TriggeredDataChangeViolation(ClassTriggeredDataChangeViolation, imp.OperationalError):
    pgcode = '27000'

class InvalidAuthorizationSpecification(ClassInvalidAuthorizationSpecification, imp.OperationalError):
    pgcode = '28000'

class InvalidPassword(ClassInvalidAuthorizationSpecification, imp.OperationalError):
    pgcode = '28P01'

class DependentPrivilegeDescriptorsStillExist(ClassDependentPrivilegeDescriptorsStillExist, imp.InternalError):
    pgcode = '2B000'

class DependentObjectsStillExist(ClassDependentPrivilegeDescriptorsStillExist, imp.InternalError):
    pgcode = '2BP01'

class InvalidTransactionTermination(ClassInvalidTransactionTermination, imp.InternalError):
    pgcode = '2D000'

class SqlRoutineException(ClassSqlRoutineException, imp.InternalError):
    pgcode = '2F000'

class FunctionExecutedNoReturnStatement(ClassSqlRoutineException, imp.InternalError):
    pgcode = '2F005'

class InvalidCursorName(ClassInvalidCursorName, imp.OperationalError):
    pgcode = '34000'

UndefinedCursor = InvalidCursorName

class ExternalRoutineException(ClassExternalRoutineException, imp.InternalError):
    pgcode = '38000'

class ContainingSqlNotPermitted(ClassExternalRoutineException, imp.InternalError):
    pgcode = '38001'

class ModifyingSqlDataNotPermitted(ClassExternalRoutineException, imp.InternalError):
    pgcode = '38002'

class ProhibitedSqlStatementAttempted(ClassExternalRoutineException, imp.InternalError):
    pgcode = '38003'

class ReadingSqlDataNotPermitted(ClassExternalRoutineException, imp.InternalError):
    pgcode = '38004'

class ExternalRoutineInvocationException(ClassExternalRoutineInvocationException, imp.InternalError):
    pgcode = '39000'

class InvalidSqlstateReturned(ClassExternalRoutineInvocationException, imp.InternalError):
    pgcode = '39001'

class NullValueNotAllowed(ClassExternalRoutineInvocationException, imp.InternalError):
    pgcode = '39004'

class TriggerProtocolViolated(ClassExternalRoutineInvocationException, imp.InternalError):
    pgcode = '39P01'

class SrfProtocolViolated(ClassExternalRoutineInvocationException, imp.InternalError):
    pgcode = '39P02'

class SavepointException(ClassSavepointException, imp.InternalError):
    pgcode = '3B000'

class InvalidSavepointSpecification(ClassSavepointException, imp.InternalError):
    pgcode = '3B001'

class InvalidCatalogName(ClassInvalidCatalogName, imp.ProgrammingError):
    pgcode = '3D000'

UndefinedDatabase = InvalidCatalogName

class InvalidSchemaName(ClassInvalidSchemaName, imp.ProgrammingError):
    pgcode = '3F000'

UndefinedSchema = InvalidSchemaName

class TransactionRollback(ClassTransactionRollback, imp.TransactionRollbackError):
    pgcode = '40000'

class SerializationFailure(ClassTransactionRollback, imp.TransactionRollbackError):
    pgcode = '40001'

class TransactionIntegrityConstraintViolation(ClassTransactionRollback, imp.TransactionRollbackError):
    pgcode = '40002'

class StatementCompletionUnknown(ClassTransactionRollback, imp.TransactionRollbackError):
    pgcode = '40003'

class DeadlockDetected(ClassTransactionRollback, imp.TransactionRollbackError):
    pgcode = '40P01'

class SyntaxErrorOrAccessRuleViolation(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42000'

class InsufficientPrivilege(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42501'

class SyntaxError(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42601'

class InvalidName(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42602'

class InvalidColumnDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42611'

class NameTooLong(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42622'

class DuplicateColumn(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42701'

class AmbiguousColumn(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42702'

class UndefinedColumn(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42703'

class UndefinedObject(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42704'

class DuplicateObject(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42710'

class DuplicateAlias(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42712'

class DuplicateFunction(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42723'

class AmbiguousFunction(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42725'

class GroupingError(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42803'

class DatatypeMismatch(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42804'

class WrongObjectType(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42809'

class InvalidForeignKey(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42830'

class CannotCoerce(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42846'

class UndefinedFunction(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42883'

class ReservedName(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42939'

class UndefinedTable(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P01'

class UndefinedParameter(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P02'

class DuplicateCursor(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P03'

class DuplicateDatabase(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P04'

class DuplicatePreparedStatement(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P05'

class DuplicateSchema(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P06'

class DuplicateTable(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P07'

class AmbiguousParameter(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P08'

class AmbiguousAlias(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P09'

class InvalidColumnReference(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P10'

class InvalidCursorDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P11'

class InvalidDatabaseDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P12'

class InvalidFunctionDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P13'

class InvalidPreparedStatementDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P14'

class InvalidSchemaDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P15'

class InvalidTableDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P16'

class InvalidObjectDefinition(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P17'

class IndeterminateDatatype(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P18'

class InvalidRecursion(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P19'

class WindowingError(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P20'

class CollationMismatch(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P21'

class IndeterminateCollation(ClassSyntaxErrorOrAccessRuleViolation, imp.ProgrammingError):
    pgcode = '42P22'

class WithCheckOptionViolation(ClassWithCheckOptionViolation, imp.ProgrammingError):
    pgcode = '44000'

class InsufficientResources(ClassInsufficientResources, imp.OperationalError):
    pgcode = '53000'

class DiskFull(ClassInsufficientResources, imp.OperationalError):
    pgcode = '53100'

class OutOfMemory(ClassInsufficientResources, imp.OperationalError):
    pgcode = '53200'

class TooManyConnections(ClassInsufficientResources, imp.OperationalError):
    pgcode = '53300'

class ConfigurationLimitExceeded(ClassInsufficientResources, imp.OperationalError):
    pgcode = '53400'

class ProgramLimitExceeded(ClassProgramLimitExceeded, imp.OperationalError):
    pgcode = '54000'

class StatementTooComplex(ClassProgramLimitExceeded, imp.OperationalError):
    pgcode = '54001'

class TooManyColumns(ClassProgramLimitExceeded, imp.OperationalError):
    pgcode = '54011'

class TooManyArguments(ClassProgramLimitExceeded, imp.OperationalError):
    pgcode = '54023'

class ObjectNotInPrerequisiteState(ClassObjectNotInPrerequisiteState, imp.OperationalError):
    pgcode = '55000'

class ObjectInUse(ClassObjectNotInPrerequisiteState, imp.OperationalError):
    pgcode = '55006'

class CantChangeRuntimeParam(ClassObjectNotInPrerequisiteState, imp.OperationalError):
    pgcode = '55P02'

class LockNotAvailable(ClassObjectNotInPrerequisiteState, imp.OperationalError):
    pgcode = '55P03'

class OperatorIntervention(ClassOperatorIntervention, imp.OperationalError):
    pgcode = '57000'

class QueryCanceled(ClassOperatorIntervention, imp.QueryCanceledError):
    pgcode = '57014'

class AdminShutdown(ClassOperatorIntervention, imp.OperationalError):
    pgcode = '57P01'

class CrashShutdown(ClassOperatorIntervention, imp.OperationalError):
    pgcode = '57P02'

class CannotConnectNow(ClassOperatorIntervention, imp.OperationalError):
    pgcode = '57P03'

class DatabaseDropped(ClassOperatorIntervention, imp.OperationalError):
    pgcode = '57P04'

class SystemError(ClassSystemError, imp.OperationalError):
    pgcode = '58000'

class IoError(ClassSystemError, imp.OperationalError):
    pgcode = '58030'

class UndefinedFile(ClassSystemError, imp.OperationalError):
    pgcode = '58P01'

class DuplicateFile(ClassSystemError, imp.OperationalError):
    pgcode = '58P02'

class ConfigFileError(ClassConfigurationFileError, imp.InternalError):
    pgcode = 'F0000'

class LockFileExists(ClassConfigurationFileError, imp.InternalError):
    pgcode = 'F0001'

class FdwError(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV000'

class FdwOutOfMemory(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV001'

class FdwDynamicParameterValueNeeded(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV002'

class FdwInvalidDataType(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV004'

class FdwColumnNameNotFound(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV005'

class FdwInvalidDataTypeDescriptors(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV006'

class FdwInvalidColumnName(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV007'

class FdwInvalidColumnNumber(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV008'

class FdwInvalidUseOfNullPointer(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV009'

class FdwInvalidStringFormat(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00A'

class FdwInvalidHandle(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00B'

class FdwInvalidOptionIndex(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00C'

class FdwInvalidOptionName(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00D'

class FdwOptionNameNotFound(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00J'

class FdwReplyHandle(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00K'

class FdwUnableToCreateExecution(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00L'

class FdwUnableToCreateReply(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00M'

class FdwUnableToEstablishConnection(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00N'

class FdwNoSchemas(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00P'

class FdwSchemaNotFound(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00Q'

class FdwTableNotFound(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV00R'

class FdwFunctionSequenceError(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV010'

class FdwTooManyHandles(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV014'

class FdwInconsistentDescriptorInformation(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV021'

class FdwInvalidAttributeValue(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV024'

class FdwInvalidStringLengthOrBufferLength(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV090'

class FdwInvalidDescriptorFieldIdentifier(ClassForeignDataWrapperError, imp.OperationalError):
    pgcode = 'HV091'

class PlpgsqlError(ClassPlPgsqlError, imp.InternalError):
    pgcode = 'P0000'

class RaiseException(ClassPlPgsqlError, imp.InternalError):
    pgcode = 'P0001'

class NoDataFound(ClassPlPgsqlError, imp.InternalError):
    pgcode = 'P0002'

class TooManyRows(ClassPlPgsqlError, imp.InternalError):
    pgcode = 'P0003'

class InternalError(ClassInternalError, imp.InternalError):
    pgcode = 'XX000'

class DataCorrupted(ClassInternalError, imp.InternalError):
    pgcode = 'XX001'

class IndexCorrupted(ClassInternalError, imp.InternalError):
    pgcode = 'XX002'
