USE [MiTest]
GO
/****** Object:  StoredProcedure [dbo].[Sp_Actualizar]    Script Date: 13/08/2024 17:27:55 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Sp_Actualizar]
    @TableName NVARCHAR(128)
AS
BEGIN
    DECLARE @Parametros NVARCHAR(MAX) = ''
    DECLARE @ColumnaLista NVARCHAR(MAX) = ''
    DECLARE @IdPK NVARCHAR(128) = ''
    DECLARE @SQL NVARCHAR(MAX) = ''
	DECLARE @Espacio varchar(5)='     '
    DECLARE @Char10Espacio NVARCHAR(6) = CHAR(10)+@Espacio;
	DECLARE @SaltoLinea varchar(72)=@Char10Espacio+'------------------------------------------------------------'+@Char10Espacio

	--Validar columnas
	DECLARE @Validar NVARCHAR(MAX) = ''
	DECLARE @NombreColumna NVARCHAR(128)
	DECLARE @TipoDato NVARCHAR(128)
	DECLARE @Nulo VARCHAR(3)

	--Acciones
	DECLARE @Insert NVARCHAR(MAX) = ''
	DECLARE @Update NVARCHAR(MAX) = ''
	DECLARE @UpdateLista NVARCHAR(MAX)=''
	DECLARE @Delete NVARCHAR(MAX)=''
	DECLARE @DeleteLista NVARCHAR(MAX) = '';
	DECLARE @FKs TABLE (
		FK_TablaForanea NVARCHAR(128),
		FK_ColumnaForanea NVARCHAR(128),
		PK_Columna NVARCHAR(128)
	);

    -- Obtener la clave primaria
    SELECT @IdPK = COLUMN_NAME
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE TABLE_NAME = @TableName
      AND OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_NAME), 'IsPrimaryKey') = 1;

    -- Generar la lista de columnas y los parámetros para el SP
    SELECT 
        @Parametros = @Parametros+@Espacio + '@'+COLUMN_NAME + ' ' + DATA_TYPE + CASE WHEN CHARACTER_MAXIMUM_LENGTH IS NOT NULL THEN '(' + CAST(CHARACTER_MAXIMUM_LENGTH AS NVARCHAR) + ')' ELSE '' END + ' = NULL,' + CHAR(10),
        @ColumnaLista = @ColumnaLista +@Espacio+ COLUMN_NAME +',' + CHAR(10)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName
      AND COLUMN_NAME <> @IdPK;

    -- Eliminar la última coma y salto de línea
    SET @Parametros = LEFT(@Parametros, LEN(@Parametros) - 2)
    SET @ColumnaLista = LEFT(@ColumnaLista, LEN(@ColumnaLista) - 2)
	---
	--Validar datos
	-- Cursor para recorrer las columnas de la tabla
	DECLARE ColumnCursor CURSOR FOR
	SELECT '@'+COLUMN_NAME, 
	DATA_TYPE,
	IS_NULLABLE
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @TableName

	OPEN ColumnCursor

	FETCH NEXT FROM ColumnCursor INTO @NombreColumna, @TipoDato, @Nulo
	

	SET @Validar = 'IF @Accion IS NULL OR @Accion NOT IN (''I'',''U'',''D'')'
	+@Char10Espacio+'BEGIN'
	+@Char10Espacio+@Espacio+'RAISERROR(''El campo Accion no puede ser nulo o esta fuera de parametro'', 16, 1)'
	--+@Char10Espacio + @Espacio + 'SET @SPError = @SPError + Char(10)'+ 
	+@Char10Espacio+'END'
	SET @Validar = 'IF @Accion IN (''U'',''D'')' 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Generar validaciones según el tipo de dato y si es nulo o no
		IF @TipoDato IN ('varchar', 'nvarchar', 'char', 'text')
		BEGIN
			SET @Validar = @Validar+@Char10Espacio +
			 CASE 
				WHEN @Nulo = 'NO' 
				THEN 'IF (' + @NombreColumna + ' IS NULL OR ' + @NombreColumna + ' = '''') ' +@Char10Espacio +
					 'BEGIN' + @Char10Espacio + @Espacio + 
					 'RAISERROR(''El campo ' + replace(@NombreColumna, '@', '') + ' no puede ser nulo.'', 16, 1)' +@Char10Espacio +@Espacio+
					 'SET @SPError = @SPError + Char(10)+ ''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede estar vacio.'''+
					 @Char10Espacio + 'END'
				ELSE '--IF (' + @NombreColumna + ' IS NULL OR ' + @NombreColumna + ' = '''') ' +@Char10Espacio +
					 '--BEGIN' + @Char10Espacio + @Espacio + 
					 '--RAISERROR(''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede estar vacio.'', 16, 1)' +@Char10Espacio +@Espacio+
					 '--SET @SPError = @SPError + Char(10)+ ''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede estar vacio.'''+
					 @Char10Espacio + '--END'
			END
		END
		ELSE IF @TipoDato IN ('int', 'bigint', 'smallint', 'tinyint', 'decimal', 'numeric', 'float', 'real')
		BEGIN
			SET @Validar = @Validar+@Char10Espacio +
			 CASE 
				WHEN @Nulo = 'NO' 
				THEN 'IF (' + @NombreColumna + ' IS NULL OR ' + @NombreColumna + ' = 0 ) ' + @Char10Espacio +
					 'BEGIN' + @Char10Espacio + @Espacio + 
					 'RAISERROR(''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'', 16, 1)' + @Char10Espacio + @Espacio + 
					 'SET @SPError = @SPError + Char(10)+ ''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'''+
					 @Char10Espacio + 'END'
				ELSE '--IF (' + @NombreColumna + ' IS NULL OR ' + @NombreColumna + ' = 0 ) ' + @Char10Espacio +
					 '--BEGIN' + @Char10Espacio + @Espacio + 
					 '--RAISERROR(''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'', 16, 1)' + @Char10Espacio + @Espacio + 
					 '--SET @SPError = @SPError + Char(10)+ ''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'''+
					 @Char10Espacio + '--END'
			END
		END
		ELSE IF @TipoDato IN ('date', 'datetime', 'datetime2', 'smalldatetime')
		BEGIN
			SET @Validar = @Validar+@Char10Espacio +
				 CASE 
					WHEN @Nulo = 'NO' 
					THEN 'IF (' + @NombreColumna + ' IS NULL OR ISDATE(' + @NombreColumna + ') = 0 '+@Char10Espacio +
						 'BEGIN' + @Char10Espacio + @Espacio + 
						 'RAISERROR(''El campo ' + @NombreColumna + ' no puede ser nulo.'', 16, 1)' + @Char10Espacio + @Espacio + 
						 'SET @SPError = @SPError + Char(10)+ ''El campo ' + @NombreColumna + ' no puede ser nulo.'''+
						 @Char10Espacio + 'END'
					ELSE '--IF (' + @NombreColumna +' IS NULL OR ISDATE(' + @NombreColumna + ') = 0 ' +@Char10Espacio +
						 '--BEGIN' + @Char10Espacio + @Espacio + 
						 '--RAISERROR(''El campo ' + replace(@NombreColumna, '@', '')  + ' no contiene una fecha válida.'', 16, 1)'+ @Char10Espacio + @Espacio + 
						 '--SET @SPError = @SPError + Char(10)+ ''El campo ' + @NombreColumna + ' no puede ser nulo.''' + 
							@Char10Espacio + '--END'
				END	
		END
		ELSE IF @TipoDato = 'bit'
		BEGIN
			SET @Validar = @Validar+@Char10Espacio  +
			 CASE 
					WHEN @Nulo = 'NO' 
					THEN 'IF (' + @NombreColumna + ' IS NULL OR ' + @NombreColumna + ' NOT IN (''0'', ''1'', ''true'', ''false'', ''yes'', ''no'') ' +@Char10Espacio +
						 'BEGIN' + @Char10Espacio + @Espacio + 
						 'RAISERROR(''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'', 16, 1)' + @Char10Espacio + @Espacio + 
						 'SET @SPError = @SPError + Char(10)+ ''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'''+ @Char10Espacio + @Espacio + 
							@Char10Espacio + '--END'
					ELSE '--IF (' + @NombreColumna +' IS NULL OR ' + @NombreColumna + ' NOT IN (''0'', ''1'', ''true'', ''false'', ''yes'', ''no'') ' +@Char10Espacio +
						 '--BEGIN' + @Char10Espacio + @Espacio + 
						 '--RAISERROR(''El campo ' + replace(@NombreColumna, '@', '')  + ' contiene un valor no válido para un bit.'', 16, 1)'+ @Char10Espacio + @Espacio + 
						 '--SET @SPError = @SPError + Char(10)+ ''El campo ' + replace(@NombreColumna, '@', '')  + ' no puede ser nulo.'''+ @Char10Espacio + @Espacio + 
							@Char10Espacio + '--END'
				END	
		END
		-- Añadir una varible para mostrar todos los errores
		FETCH NEXT FROM ColumnCursor INTO @NombreColumna, @TipoDato, @Nulo
	END

	CLOSE ColumnCursor
	DEALLOCATE ColumnCursor

	--INSERT 
	set @Insert='IF @Accion = ''I'''+@Char10Espacio+'BEGIN'+@Char10Espacio+@Espacio+
	'INSERT INTO ' + @TableName + ' ( '
	+CHAR(10) + REPLACE(@ColumnaLista, @Espacio, @Espacio+@Espacio+@Espacio) + 
	+@Char10Espacio+@Espacio+
	') VALUES (' +@Espacio+@Espacio+CHAR(10)
	+ REPLACE(@ColumnaLista, @Espacio, @Espacio+@Espacio+@Espacio+'@') +@Char10Espacio+@Espacio+
	');'
	+@Char10Espacio+@Espacio+'SET @'+@IdPK+' = @@IDENTITY'+
	+@Char10Espacio+
	'END'

	--UPDATE

	SELECT @UpdateLista = @UpdateLista + @Espacio + @Espacio + @Espacio + replace (value,','+char(10), ' ' )+ '= @'+value
	FROM STRING_SPLIT(replace(@ColumnaLista, @espacio, '.'),'.')
	WHERE TRIM(value) <> ''

	SET @Update = 'IF @Accion = ''U''' + CHAR(10) + 
              @Espacio + 'BEGIN' + CHAR(10) + 
              @Espacio + @Espacio +
              'UPDATE ' + @TableName + CHAR(10) +
              @Espacio + @Espacio + 
              'SET ' + CHAR(10) + 
              @UpdateLista + CHAR(10) + 
              @Espacio + @Espacio +
              'WHERE ' + @IdPK + ' = @' + @IdPK + CHAR(10) +
              @Espacio + 'END'
	
	--DELETE
	INSERT INTO @FKs (FK_TablaForanea, FK_ColumnaForanea, PK_Columna)
	SELECT
		fk.name AS FK_TablaForanea,
		c.name AS FK_ColumnaForanea,
		pk.name AS PK_Columna
	FROM
		sys.foreign_key_columns fkc
	INNER JOIN
		sys.tables t ON fkc.referenced_object_id = t.object_id
	INNER JOIN
		sys.columns c ON fkc.parent_column_id = c.column_id AND fkc.parent_object_id = c.object_id
	INNER JOIN
		sys.tables fk ON fkc.parent_object_id = fk.object_id
	INNER JOIN
		sys.columns pk ON fkc.referenced_column_id = pk.column_id AND fkc.referenced_object_id = pk.object_id
	WHERE
		t.name = @TableName;

	-- Construye el código para eliminar los registros referenciados
	WHILE EXISTS (SELECT 1 FROM @FKs)
	BEGIN
		DECLARE @FKTablaForanea NVARCHAR(128);
		DECLARE @FKColumnaForanea NVARCHAR(128);
		DECLARE @PKColumna NVARCHAR(128);

		-- Obtén la primera clave foránea
		SELECT TOP 1 @FKTablaForanea = FK_TablaForanea,
         @FKColumnaForanea = FK_ColumnaForanea, 
         @PKColumna = PK_Columna 
        FROM @FKs;

		-- Elimina los registros en la tabla foránea
		SET @DeleteLista = @DeleteLista + 'DELETE FROM ' + @FKTablaForanea 
        +@Char10Espacio+ @Espacio + 'WHERE ' + @FKColumnaForanea + ' = @' + @IdPK + CHAR(10);

		-- Elimina la entrada de la tabla de claves foráneas
		DELETE FROM @FKs WHERE FK_TablaForanea = @FKTablaForanea;
	END

	-- Finalmente, elimina el registro de la tabla principal
	SET @Delete = 'IF @Accion = ''D''' + CHAR(10) +
				  @Espacio + 'BEGIN' + CHAR(10) +
				  @Espacio + @Espacio +
				  @DeleteLista + CHAR(10) +
				  @Espacio + @Espacio +
				  'DELETE FROM ' + @TableName + CHAR(10) +
				  @Espacio + @Espacio +
				  'WHERE ' + @IdPK + ' = @' + @IdPK + CHAR(10) +
				  @Espacio + 'END' 

	---
	SET @SQL ='CREATE PROCEDURE SP_' + @TableName + '_Actualizar'+@Char10Espacio+
    '@Accion VARCHAR(1),  -- Tipo de acción: ''I'', ''U'', ''D'' '+@Char10Espacio+'@SPError NVARCHAR(4000), '+@Char10Espacio+'@' + @IdPK + ' INT = NULL,  -- Clave primaria' +char(10)
	+ @Parametros + CHAR(10)+'AS'+CHAR(10)+'BEGIN'+CHAR(10)+'BEGIN TRY'+@Char10Espacio
	+@SaltoLinea+
	'--Validar Parametros'
	+@SaltoLinea+
	@Validar+
	+@SaltoLinea+
	+'Select @SpError'+
	+@SaltoLinea+
	'--INSERT '+@TableName+
	@SaltoLinea+
	@Insert+
	@SaltoLinea+
	'--UPDATE '+@TableName+
	@SaltoLinea+
	@Update+
	@SaltoLinea+
	'--DELETE '+@TableName+
	@SaltoLinea+
	@Delete+
	@SaltoLinea+
	+CHAR(10)+'END TRY'
	+CHAR(10)+'BEGIN CATCH'
	+@Char10Espacio+'-- Capturar y manejar errores'+@Char10Espacio+
        'DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;'+@Char10Espacio+
		'SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();'+@Char10Espacio+
		'RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);'+
	+CHAR(10)+'END CATCH'
	+CHAR(10)+'END'

print @SQL
    -- Ejecutar el SP dinámico
--EXEC sp_executesql @sql;
END;
