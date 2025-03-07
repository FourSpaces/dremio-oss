<#--

    Copyright (C) 2017-2019 Dremio Corporation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

-->

<#--
  Add implementations of additional parser statements here.
  Each implementation should return an object of SqlNode type.

  Example of SqlShowTables() implementation:
  SqlNode SqlShowTables()
  {
    ...local variables...
  }
  {
    <SHOW> <TABLES>
    ...
    {
      return SqlShowTables(...)
    }
  }
-->
/**
 * Parses statement
 *   SHOW TABLES [{FROM | IN} db_name] [LIKE 'pattern']
 */
SqlNode SqlShowTables() :
{
    SqlParserPos pos;
    SqlIdentifier db = null;
    SqlNode likePattern = null;
}
{
    <SHOW> { pos = getPos(); }
    <TABLES>
    [
        (<FROM> | <IN>) { db = CompoundIdentifier(); }
    ]
    [
        <LIKE> { likePattern = StringLiteral(); }
    ]
    {
        return new SqlShowTables(pos, db, likePattern);
    }
}

/**
 * Parses statement
 * SHOW FILES [{FROM | IN} schema]
 */
SqlNode SqlShowFiles() :
{
    SqlParserPos pos = null;
    SqlIdentifier db = null;
}
{
    <SHOW> { pos = getPos(); }
    <FILES>
    [
        (<FROM> | <IN>) { db = CompoundIdentifier(); }
    ]
    {
        return new SqlShowFiles(pos, db);
    }
}


/**
 * Parses statement SHOW {DATABASES | SCHEMAS} [LIKE 'pattern']
 */
SqlNode SqlShowSchemas() :
{
    SqlParserPos pos;
    SqlNode likePattern = null;
}
{
    <SHOW> { pos = getPos(); }
    (<DATABASES> | <SCHEMAS>)
    [
        <LIKE> { likePattern = StringLiteral(); }
    ]
    {
        return new SqlShowSchemas(pos, likePattern);
    }
}

/**
 * Parses statement
 *   { DESCRIBE | DESC } tblname [col_name | wildcard ]
 */
SqlNode SqlDescribeTable() :
{
    SqlParserPos pos;
    SqlIdentifier table;
    SqlIdentifier column = null;
}
{
    (<DESCRIBE> | <DESC>) { pos = getPos(); }
    table = CompoundIdentifier()
    (
        column = CompoundIdentifier()
        |
        E()
    )
    {
        return new SqlDescribeTable(pos, table, column);
    }
}

SqlNode SqlUseSchema():
{
    SqlIdentifier schema;
    SqlParserPos pos;
}
{
    <USE> { pos = getPos(); }
    schema = CompoundIdentifier()
    {
        return new SqlUseSchema(pos, schema);
    }
}

/** Parses an optional field list and makes sure no field is a "*". */
SqlNodeList ParseOptionalFieldList(String relType) :
{
    SqlNodeList fieldList;
}
{
    fieldList = ParseRequiredFieldList(relType)
    {
        return fieldList;
    }
    |
    {
        return SqlNodeList.EMPTY;
    }
}

/** Parses a required field list and makes sure no field is a "*". */
SqlNodeList ParseRequiredFieldList(String relType) :
{
    SqlNodeList fieldList = new SqlNodeList(getPos());
}
{
    <LPAREN>
    SimpleIdentifierCommaList(fieldList.getList())
    <RPAREN>
    {
        for(SqlNode node : fieldList)
        {
            if (((SqlIdentifier)node).isStar())
                throw new ParseException(String.format("%s's field list has a '*', which is invalid.", relType));
        }
        return fieldList;
    }
}

/**
 * Parses a create view or replace existing view statement.
 *   CREATE [OR REPLACE] VIEW view_name [ (field1, field2 ...) ] AS select_statement
 */
SqlNode SqlCreateOrReplaceView() :
{
    SqlParserPos pos;
    boolean replaceView = false;
    SqlIdentifier viewName;
    SqlNode query;
    SqlNodeList fieldList;
}
{
    <CREATE> { pos = getPos(); }
    [ <OR> <REPLACE> { replaceView = true; } ]
    (<VIEW>|<VDS>)
    viewName = CompoundIdentifier()
    fieldList = ParseOptionalFieldList("View")
    <AS>
    query = OrderedQueryOrExpr(ExprContext.ACCEPT_QUERY)
    {
        return new SqlCreateView(pos, viewName, fieldList, query, replaceView);
    }
}

/**
 * Parses a drop view or drop view if exists statement.
 * DROP VIEW [IF EXISTS] view_name;
 */
SqlNode SqlDropView() :
{
    SqlParserPos pos;
    boolean viewExistenceCheck = false;
}
{
    <DROP> { pos = getPos(); }
    ( <VIEW> | <VDS> )
    [ <IF> <EXISTS> { viewExistenceCheck = true; } ]
    {
        return new SqlDropView(pos, CompoundIdentifier(), viewExistenceCheck);
    }
}

SqlNodeList TableElementList() :
{
    final Span s;
    final List<SqlNode> list = new ArrayList<SqlNode>();
}
{
    <LPAREN> { s = span(); }
    TableElement(list)
    (
        <COMMA> TableElement(list)
    )*
    <RPAREN> {
        return new SqlNodeList(list, s.end(this));
    }
}

void TableElement(List<SqlNode> list) :
{
    final SqlIdentifier id;
    final SqlDataTypeSpec type;
    final boolean nullable;
    final SqlNode e;
    final SqlNode constraint;
    SqlIdentifier name = null;
    final SqlNodeList columnList;
    final Span s = Span.of();
}
{
    LOOKAHEAD(2) id = SimpleIdentifier()
    (
        type = DataType()
        nullable = NullableOptDefaultTrue()
        {
            list.add(
                    new SqlColumnDeclaration(s.add(id).end(this), id,
                    new SqlComplexDataTypeSpec(type.withNullable(nullable)), null));
        }
        |
        { list.add(id); }
    )
    |
    id = SimpleIdentifier() {
        list.add(id);
    }
}

/**
 * Parses a CTAS statement.
 * CREATE TABLE tblname [ (field1, field2, ...) ]
 *       [ (STRIPED, HASH, ROUNDROBIN) PARTITION BY (field1, field2, ..) ]
 *       [ DISTRIBUTE BY (field1, field2, ..) ]
 *       [ LOCALSORT BY (field1, field2, ..) ]
 *       [ STORE AS (opt1 => val1, opt2 => val3, ...) ]
 *       [ WITH SINGLE WRITER ]
 *       [ AS select_statement. ]
 */
SqlNode SqlCreateTable() :
{
    SqlParserPos pos;
    SqlIdentifier tblName;
    SqlNodeList fieldList;
    List<SqlNode> formatList = new ArrayList();
    SqlNodeList formatOptions;
    PartitionDistributionStrategy partitionDistributionStrategy;
    SqlNodeList partitionFieldList;
    SqlNodeList distributeFieldList;
    SqlNodeList sortFieldList;
    SqlLiteral singleWriter;
    SqlNode query;
}
{
    {
        partitionFieldList = SqlNodeList.EMPTY;
        distributeFieldList = SqlNodeList.EMPTY;
        sortFieldList =  SqlNodeList.EMPTY;
        formatOptions = SqlNodeList.EMPTY;
        singleWriter = SqlLiteral.createBoolean(false, SqlParserPos.ZERO);
        partitionDistributionStrategy = PartitionDistributionStrategy.UNSPECIFIED;
        fieldList = SqlNodeList.EMPTY;
    }
    <CREATE> { pos = getPos(); }
    <TABLE>
    tblName = CompoundIdentifier()
    [ fieldList = TableElementList() ]
    (
        (
            <STRIPED> {
                partitionDistributionStrategy = PartitionDistributionStrategy.STRIPED;
            }
        |
            <HASH> {
                partitionDistributionStrategy = PartitionDistributionStrategy.HASH;
            }
        |
            <ROUNDROBIN> {
                partitionDistributionStrategy = PartitionDistributionStrategy.ROUND_ROBIN;
            }
        )?
        <PARTITION> <BY>
        partitionFieldList = ParseRequiredFieldList("Partition")
    )?
    (   <DISTRIBUTE> <BY>
        distributeFieldList = ParseRequiredFieldList("Distribution")
    )?
    (   <LOCALSORT> <BY>
        sortFieldList = ParseRequiredFieldList("Sort")
    )?    
    [
        <STORE> <AS>
        <LPAREN>
            Arg0(formatList, ExprContext.ACCEPT_CURSOR)
            (
                <COMMA>
                Arg(formatList, ExprContext.ACCEPT_CURSOR)
            )*
        <RPAREN>
        {
            formatOptions = new SqlNodeList(formatList, getPos());
        }
    ]
    [
        <WITH><SINGLE><WRITER>
        {
            singleWriter = SqlLiteral.createBoolean(true, getPos());
        }
    ]
        (
            (
                <AS>
                query = OrderedQueryOrExpr(ExprContext.ACCEPT_QUERY)
                {
                    return new SqlCreateTable(pos, tblName, fieldList, partitionDistributionStrategy, partitionFieldList,
                    formatOptions, singleWriter, sortFieldList, distributeFieldList, query);
                }
            )
            |
            (
                {
                    return new SqlCreateEmptyTable(pos, tblName, fieldList, partitionDistributionStrategy,
                    partitionFieldList, formatOptions, singleWriter, sortFieldList, distributeFieldList);
                }
            )
        )
}

/**
* Parses a insert table or drop table if exists statement.
* INSERT INTO table_name select_statement;
*/
SqlNode SqlInsertTable() :
{
  SqlParserPos pos;
  SqlIdentifier tblName;
  SqlNode query;
  SqlNodeList fieldList;
}
{
  {
    fieldList = SqlNodeList.EMPTY;
  }

  <INSERT> { pos = getPos(); }
  <INTO>
    tblName = CompoundIdentifier()
    [ fieldList = TableElementList() ]
    query = OrderedQueryOrExpr(ExprContext.ACCEPT_QUERY)
    {
      return new SqlInsertTable(pos, tblName, query, fieldList);
    }
}

/**
 * Parses a drop table or drop table if exists statement.
 * DROP TABLE [IF EXISTS] table_name;
 */
SqlNode SqlDropTable() :
{
    SqlParserPos pos;
    boolean tableExistenceCheck = false;
}
{
    <DROP> { pos = getPos(); }
    <TABLE>
    [ <IF> <EXISTS> { tableExistenceCheck = true; } ]
    {
        return new SqlDropTable(pos, CompoundIdentifier(), tableExistenceCheck);
    }
}

/**
 * Parses a truncate table statement.
 * TRUNCATE [TABLE] [IF EXISTS] table_name;
 */
SqlNode SqlTruncateTable() :
{
    SqlParserPos pos;
    boolean tableExistenceCheck = false;
    boolean tableKeywordPresent = false;
}
{
    <TRUNCATE> { pos = getPos(); }
    [ <TABLE> { tableKeywordPresent = true; } ]
    [ <IF> <EXISTS> { tableExistenceCheck = true; } ]
    {
        return new SqlTruncateTable(pos, CompoundIdentifier(), tableExistenceCheck, tableKeywordPresent);
    }
}

/**
 * Parses a $REFRESH REFLECTION statement
 *   $REFRESH REFLECTION reflectionId AS materializationId
 */
SqlNode SqlRefreshReflection() :
{
    SqlParserPos pos;
    SqlNode reflectionId;
    SqlNode materializationId;
}
{
    <REFRESH> { pos = getPos(); }
    <REFLECTION>
    { reflectionId = StringLiteral(); }
    <AS>
    { materializationId = StringLiteral(); }
    {
        return new SqlRefreshReflection(pos, reflectionId, materializationId);
    }
}

/**
 * Parses a LOAD MATERIALIZATION statement
 *   $LOAD MATERIALIZATION METADATA materialization_path
 */
SqlNode SqlLoadMaterialization() :
{
    SqlParserPos pos;
    SqlIdentifier materializationPath;
}
{
    <LOAD> { pos = getPos(); }
    <MATERIALIZATION> <METADATA>
    { materializationPath = CompoundIdentifier(); }
    {
        return new SqlLoadMaterialization(pos, materializationPath);
    }
}


/**
 * Parses a COMPACT REFRESH statement
 *   $COMPACT MATERIALIZATION materialization_path AS materializationId
 */
SqlNode SqlCompactMaterialization() :
{
    SqlParserPos pos;
    SqlIdentifier materializationPath;
    SqlNode newMaterializationId;
}
{
    <COMPACT> { pos = getPos(); }
    <MATERIALIZATION>
    { materializationPath = CompoundIdentifier(); }
    <AS>
    { newMaterializationId = StringLiteral(); }
    {
        return new SqlCompactMaterialization(pos, materializationPath, newMaterializationId);
    }
}

/**
 * Parses a ANALYZE TABLE STATISTICS
 */
SqlNode SqlAnalyzeTableStatistics() :
{
    final SqlParserPos pos;
    final SqlIdentifier table;
    SqlLiteral isAnalyze = SqlLiteral.createBoolean(true, SqlParserPos.ZERO);
    SqlNodeList columns = SqlNodeList.EMPTY;
}
{
    <ANALYZE> { pos = getPos(); }
    <TABLE> { table = CompoundIdentifier(); }
    <FOR>
      (
        <ALL> <COLUMNS> { columns = SqlNodeList.EMPTY; }
        |
        <COLUMNS> { columns = ParseOptionalFieldList("Columns"); }
      )
    (
      <COMPUTE> <STATISTICS> { isAnalyze = SqlLiteral.createBoolean(true, SqlParserPos.ZERO); }
      |
      <DELETE> <STATISTICS> { isAnalyze = SqlLiteral.createBoolean(false, SqlParserPos.ZERO); }
    )
    { return new SqlAnalyzeTableStatistics(pos, table, isAnalyze, columns); }
}

/**
 * Parses a REFRESH DATASET table_name statement
 */
SqlNode SqlRefreshDataset() :
{
    SqlParserPos pos;
    SqlIdentifier tblName;
    SqlLiteral deleteUnavail = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlLiteral promotion = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlLiteral forceUp = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlLiteral allFilesRefresh = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlLiteral allPartitionsRefresh = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlLiteral fileRefresh = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlLiteral partitionRefresh = SqlLiteral.createNull(SqlParserPos.ZERO);
    SqlNodeList filesList = SqlNodeList.EMPTY;
    SqlNodeList partitionList = SqlNodeList.EMPTY;
}
{
    <REFRESH> { pos = getPos(); }
    <DATASET>
    { tblName = CompoundIdentifier(); }
    (
      <FOR> <ALL>
      (
        <FILES> { allFilesRefresh = SqlLiteral.createBoolean(true, pos); }
      |
        <PARTITIONS> { allPartitionsRefresh = SqlLiteral.createBoolean(true, pos); }
      )
    |
      <FOR> <FILES> {
        fileRefresh = SqlLiteral.createBoolean(true, pos);
        filesList = ParseRequiredFilesList();
      }
    |
      <FOR> <PARTITIONS> {
        partitionRefresh = SqlLiteral.createBoolean(true, pos);
        partitionList = ParseRequiredPartitionList();
      }
    )?
    (
      <AUTO> <PROMOTION> { promotion = SqlLiteral.createBoolean(true, pos); }
    |
      <AVOID> <PROMOTION> { promotion = SqlLiteral.createBoolean(false, pos); }
    )?
    (
      <FORCE> <UPDATE> { forceUp = SqlLiteral.createBoolean(true, pos); }
    |
      <LAZY> <UPDATE> { forceUp = SqlLiteral.createBoolean(false, pos); }
    )?
    (
      <DELETE> <WHEN> <MISSING> { deleteUnavail = SqlLiteral.createBoolean(true, pos); }
    |
      <MAINTAIN> <WHEN> <MISSING> { deleteUnavail = SqlLiteral.createBoolean(false, pos); }
    )?
    { return new SqlRefreshDataset(pos, tblName, deleteUnavail, forceUp, promotion, allFilesRefresh,
        allPartitionsRefresh, fileRefresh, partitionRefresh, filesList, partitionList); }
}

/**
 * Parse a nullable option, default is true.
 */
 boolean NullableOptDefaultTrue() :
 {
 }
 {
     <NULL> { return true; }
 |
     <NOT> <NULL> { return false; }
 |
     { return true; }
 }


/**
 * Parse a "name1 : type1 [NULL | NOT NULL], name2: type2 [NULL | NOT NULL] ..." list,
 * the field type default is nullable.
 */
 void FieldNameStructTypeCommaList(
         List<SqlIdentifier> fieldNames,
         List<SqlComplexDataTypeSpec> fieldTypes) :
 {
     SqlIdentifier fName;
     SqlDataTypeSpec fType;
     boolean nullable;
 }
 {
     fName = SimpleIdentifier()
     <COLON>
     fType = DataType()
     nullable = NullableOptDefaultTrue()
     {
         fieldNames.add(fName);
         fieldTypes.add(new SqlComplexDataTypeSpec(fType.withNullable(nullable)));
     }
     (
         <COMMA>
         fName = SimpleIdentifier()
         <COLON>
         fType = DataType()
         nullable = NullableOptDefaultTrue()
         {
             fieldNames.add(fName);
             fieldTypes.add(new SqlComplexDataTypeSpec(fType.withNullable(nullable)));
         }
     )*
 }

 /**
 * Parse Row type with format: struct<name1 : type1, name2: type2>.
 * Every item type can have suffix of `NULL` or `NOT NULL` to indicate if this type is nullable.
 * i.e. struct<name1 : type1 not null, name2: type2 null>.
 */
 SqlIdentifier RowTypeName() :
 {
     List<SqlIdentifier> fieldNames = new ArrayList<SqlIdentifier>();
     List<SqlComplexDataTypeSpec> fieldTypes = new ArrayList<SqlComplexDataTypeSpec>();
 }
 {
     <STRUCT>
     <LT> FieldNameStructTypeCommaList(fieldNames, fieldTypes) <GT>
     {
         return new SqlRowTypeSpec(getPos(), fieldNames, fieldTypes);
     }
 }

 /**
  * Parse Array type with format: list<type1>.
  * Every item type can have suffix of `NULL` or `NOT NULL` to indicate if this type is nullable.
  * i.e. list<type1 not null>.
  */
  SqlIdentifier ArrayTypeName() :
  {
      SqlDataTypeSpec fType;
      boolean nullable;
  }
  {
      (<LIST> | <ARRAY>)
      <LT>
       fType = DataType()
       nullable = NullableOptDefaultTrue()
      <GT>
      {
          return new SqlArrayTypeSpec(getPos(), new SqlComplexDataTypeSpec(fType.withNullable(nullable)));
      }
  }
