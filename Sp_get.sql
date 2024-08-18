USE [MiTest]
GO
/****** Object:  StoredProcedure [dbo].[sp_GET]    Script Date: 18/08/2024 17:33:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_GET]
    @TableName NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @SpNombre NVARCHAR(255);
	DECLARE @SPInfo Nvarchar(355);
	DECLARE @Now DATETIME =GETDATE()

    DECLARE @ListaColumnas NVARCHAR(MAX) = '';
    DECLARE @Params NVARCHAR(MAX) = '';
    DECLARE @WhereFiltro NVARCHAR(MAX) = '';
    DECLARE @PKColumna NVARCHAR(MAX) = '';
    DECLARE @NobreColumna NVARCHAR(255);
    DECLARE @TipoDatos NVARCHAR(255);

    DECLARE @Espaciado varchar(20) = '         ';

    DECLARE @IndiceWhere NVARCHAR(MAX) = '';
    DECLARE @IndiceColumnas NVARCHAR(MAX) = '';
    DECLARE @CursorColumnas CURSOR;
    DECLARE @IndiceNombre NVARCHAR(MAX) = '';
    DECLARE @CursorIndeces CURSOR;

    -- Nombre del SP
    SET @SpNombre = 'SP_' + @TableName + '_GET';
	SET @SPInfo = '-- SP: '+@SpNombre +char(10)+ '-- Hora Creacion: '+convert (nvarchar(30),@Now)+ char(10)
    -- Sacar las Primary Keys
    SELECT @PKColumna = STRING_AGG(COLUMN_NAME, ', ')
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE TABLE_NAME = @TableName
      AND OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_NAME), 'IsPrimaryKey') = 1;

    -- Obtener columnas y sus tipos de datos de la tabla
    SET @CursorColumnas = CURSOR FOR
		SELECT C.COLUMN_NAME, C.DATA_TYPE
		FROM INFORMATION_SCHEMA.COLUMNS C
		WHERE C.TABLE_NAME = @TableName
		ORDER BY C.ORDINAL_POSITION;
    OPEN @CursorColumnas;
    FETCH NEXT FROM @CursorColumnas INTO @NobreColumna, @TipoDatos;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Añadir la columna a la lista de selección
        SET @ListaColumnas = @ListaColumnas +@Espaciado+ '[' + @NobreColumna + '], ' + CHAR(10);

        -- Añadir el parámetro y la condición a los filtros según el tipo de dato
        IF @TipoDatos IN ('nvarchar', 'varchar', 'nchar', 'char', 'text', 'ntext')
        BEGIN
            SET @Params = @Params + @Espaciado + '@' + @NobreColumna + ' NVARCHAR(255) = NULL, ';
			SET @WhereFiltro = @WhereFiltro + @Espaciado + '(@' + @NobreColumna + ' IS NULL OR [' + @NobreColumna + '] LIKE ''%'' + @' + @NobreColumna + ' + ''%'') AND ';
        END
        ELSE IF @TipoDatos IN ('int', 'bigint', 'smallint', 'tinyint', 'float', 'decimal', 'numeric', 'real', 'money', 'smallmoney')
        BEGIN
            SET @Params = @Params + @Espaciado + '@' + @NobreColumna + ' ' + @TipoDatos + ' = NULL, ';
			SET @WhereFiltro = @WhereFiltro +@Espaciado +  '(@' + @NobreColumna + ' IS NULL OR [' + @NobreColumna + '] = @' + @NobreColumna + ') AND ';
		END
        ELSE IF @TipoDatos IN ('date', 'datetime', 'smalldatetime', 'datetime2', 'time')
        BEGIN
            SET @Params = @Params + @Espaciado + '@' + @NobreColumna + ' ' + @TipoDatos + ' = NULL, ';           
			SET @WhereFiltro = @WhereFiltro +@Espaciado +  '(@' + @NobreColumna + ' IS NULL OR [' + @NobreColumna + '] = @' + @NobreColumna + ') AND ';
        END
        ELSE IF @TipoDatos = 'bit'
        BEGIN
            SET @Params = @Params + @Espaciado + '@' + @NobreColumna + ' BIT = NULL, ';            
			SET @WhereFiltro = @WhereFiltro +@Espaciado +  '(@' + @NobreColumna + ' IS NULL OR [' + @NobreColumna + '] = @' + @NobreColumna + ') AND ';
        END
        ELSE
        BEGIN
            SET @Params = @Params + @Espaciado + '@' + @NobreColumna + ' NVARCHAR(255) = NULL, ';
			SET @WhereFiltro = @WhereFiltro +@Espaciado +  '(@' + @NobreColumna + ' IS NULL OR [' + @NobreColumna + '] LIKE ''%'' + @' + @NobreColumna + ' + ''%'') AND ';
        END
			SET @Params= @Params +CHAR(10)
			SET @WhereFiltro = @WhereFiltro + CHAR(10)

        FETCH NEXT FROM @CursorColumnas INTO @NobreColumna, @TipoDatos;
    END;

    CLOSE @CursorColumnas;
    DEALLOCATE @CursorColumnas;
	 -- Quitar la última coma y espacio de @Params
    SET @Params = LEFT(@Params, LEN(@Params) - 3);
    SET @WhereFiltro = LEFT(@WhereFiltro, LEN(@WhereFiltro) - 5);	
	SET  @ListaColumnas= LEFT (@ListaColumnas,LEN(@ListaColumnas)-3)
	--PRINT '@Params : '+ @Params
	--PRINT '@WhereFiltro : '+@WhereFiltro
	--PRINT '@ListaColumnas :' +@ListaColumnas

	-- Selección de INDICES
	SET @CursorIndeces = CURSOR FOR
	SELECT i.name AS index_name,
		c.name AS column_name
	FROM sys.indexes i 
	JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id 
	JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id 
	WHERE i.object_id = OBJECT_ID(@TableName);
	OPEN @CursorIndeces;
	FETCH NEXT FROM @CursorIndeces INTO @IndiceNombre, @IndiceColumnas;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @IndiceColumnas IS NOT NULL
		BEGIN
			-- Obtener columnas que no están en el índice
			DECLARE @NoIndiceColumnas NVARCHAR(MAX) = '';
			SELECT @NoIndiceColumnas = STRING_AGG(c.name, ',')
			FROM sys.columns c
			WHERE c.object_id = OBJECT_ID(@TableName)
			  AND c.name NOT IN (SELECT value FROM STRING_SPLIT(@IndiceColumnas, ','));

			-- Crear condición IF
			SET @IndiceWhere = @IndiceWhere +  'IF ' + '(' + '@' + REPLACE(@IndiceColumnas, ',', ' IS NOT NULL AND ') + ' IS NOT NULL';
        
			-- Agregar condición para que las columnas que no son del índice sean NULL
			IF @NoIndiceColumnas IS NOT NULL AND LEN(@NoIndiceColumnas) > 0
			BEGIN
				SET @IndiceWhere = @IndiceWhere + ' AND- ' +'@'+ REPLACE(@NoIndiceColumnas, ',', ' IS NULL AND ') + ' IS NULL';
			END
        print @IndiceWhere
			SET @IndiceWhere = @IndiceWhere + ')' + CHAR(10) +
				@Espaciado+ 'BEGIN' + CHAR(10) +
				CHAR(10) + @Espaciado+ '    SELECT '+CHAR(10)+@Espaciado+replace( @ListaColumnas,char(10),char(10)+@Espaciado) + 
				CHAR(10) + @Espaciado + '    FROM [' + @TableName + ']' + 
				CHAR(10) + @Espaciado + '    WHERE ';

			-- Crear el WHERE
			DECLARE @ColumnaIndividual NVARCHAR(255);
			DECLARE @CursorColumnaIndividual CURSOR;

			SET @CursorColumnaIndividual = CURSOR FOR
			SELECT VALUE FROM STRING_SPLIT(@IndiceColumnas, ',');

			OPEN @CursorColumnaIndividual;
			FETCH NEXT FROM @CursorColumnaIndividual INTO @ColumnaIndividual;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @ColumnaIndividual IS NOT NULL
				BEGIN
					-- Si es texto, utiliza el LIKE
					IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME = @ColumnaIndividual AND DATA_TYPE IN ('nvarchar', 'varchar', 'nchar', 'char', 'text', 'ntext'))
					BEGIN
						SET @IndiceWhere = @IndiceWhere + '([' + @ColumnaIndividual + '] LIKE ''%'' + @' + @ColumnaIndividual + ' + ''%'') AND ';
					END
					ELSE
					BEGIN
						SET @IndiceWhere = @IndiceWhere + '([' + @ColumnaIndividual + '] = @' + @ColumnaIndividual + ') AND ';
					END
				END
				FETCH NEXT FROM @CursorColumnaIndividual INTO @ColumnaIndividual;
			END;

			CLOSE @CursorColumnaIndividual;
			DEALLOCATE @CursorColumnaIndividual;

			-- Quitar el último 'AND ' y limpiar
			SET @IndiceWhere = LEFT(@IndiceWhere, LEN(@IndiceWhere) - 4) + CHAR(10) + @Espaciado + 'END' + CHAR(10) + @Espaciado;
		END

		FETCH NEXT FROM @CursorIndeces INTO @IndiceNombre, @IndiceColumnas;
	END;

	CLOSE @CursorIndeces;
	DEALLOCATE @CursorIndeces;

   
    -- SP Final
    SET @SQL = @SPInfo +' CREATE PROCEDURE ' + @SpNombre + char(10)+  @Params + ',
         @Pagina INT = 1,
         @Columnas INT = 10
    AS
    BEGIN
        SET NOCOUNT ON;

        -- Selecciones óptimas basadas en índices
        ' + @IndiceWhere + '
		-- Fin Select por indices

        -- Si no se cumple ninguna condición de índice, realizar una búsqueda genérica con paginación
        DECLARE @Offset INT;
        SET @Offset = (@Pagina - 1) * @Columnas;

        SELECT '+ CHAR(10)+ @ListaColumnas  + '
        FROM [' + @TableName + ']'+'
        WHERE ' +CHAR(10) + @WhereFiltro + '
        ORDER BY 
            ' + COALESCE(@PKColumna, '1') + ' -- Asegúrate de que haya al menos una columna para ORDER BY
        OFFSET @Offset ROWS
        FETCH NEXT @Columnas ROWS ONLY;

        -- Contar el total de registros
        SELECT COUNT(*) AS TotalRecords
        FROM [' + @TableName + ']        
        WHERE '+CHAR(10) + @WhereFiltro + '
    END
    ';

   -- PRINT @SQL;
    -- Ejecutar el script dinámico para crear el procedimiento almacenado
   -- EXEC sp_executesql @SQL;
END;
