-- TRABAJO SUMATIVO IGNACIO KRIMAN
-- GENERACION AUTOMATICA DE USUARIOS Y CLAVES PARA TRABAJADORES BAJO CRITERIOS DE NEGOCIO ESPECIFICOS

-- SERVEROUTPUT para mostrar mensajes en consola
SET SERVEROUTPUT ON;

-- variables bind para pasar valores dinamicos al bloque, en este caso seria la fecha
VARIABLE b_fecha_proceso VARCHAR2(10);
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE,'DD/MM/YYYY');

-- borrado de la tabla para poder reutilizar el codigo las veces necesarias
TRUNCATE TABLE USUARIO_CLAVE;


-- bloque PL/SQL
DECLARE
    -- variables ecalares Y %TYPE 
    v_f_proceso     DATE := TO_DATE(:b_fecha_proceso,'DD/MM/YYYY');
    v_nom_user      VARCHAR2(100);
    v_clave_user    VARCHAR2(100);
    v_antiguedad    NUMBER;
    v_letra_ec      CHAR(1);
    v_nombre_ec     VARCHAR2(50);
    v_letras_ap     VARCHAR2(2);
    v_total_rango   NUMBER;
    v_contador      NUMBER := 0;
    
    -- variable para SQL dinamico 
    v_sql_limpieza  VARCHAR2(100) := 'TRUNCATE TABLE USUARIO_CLAVE';

BEGIN
    -- truncado dinamico
    EXECUTE IMMEDIATE v_sql_limpieza;

    -- conteo dinamico para asegurar integridad y disenado para escalar
    SELECT COUNT(*) INTO v_total_rango FROM EMPLEADO;

    -- ciclo de procesamiento
    -- usamos un bucle FOR y guardamos cada fila en r
    FOR r IN (
        SELECT * FROM EMPLEADO ORDER BY id_emp
    ) LOOP

        -- obtencion de estado civil 
        SELECT nombre_estado_civil INTO v_nombre_ec FROM ESTADO_CIVIL
        WHERE id_estado_civil = r.id_estado_civil;

        v_letra_ec := LOWER(SUBSTR(v_nombre_ec,1,1));

        -- calculo de antiguedad
        -- Se utiliza MONTHS_BETWEEN
        v_antiguedad := FLOOR(MONTHS_BETWEEN(v_f_proceso, r.fecha_contrato) / 12);

        -- formato nombre de usuario
        v_nom_user := v_letra_ec || UPPER(SUBSTR(r.pnombre_emp,1,3)) ||
                      LENGTH(r.pnombre_emp) || '*' ||
                      SUBSTR(TO_CHAR(r.sueldo_base),-1) ||
                      r.dvrun_emp || v_antiguedad;

        -- usamos un ciclo IF para verificar la antiguedad de cada empleado es 
        -- menor o mayor a 10
        IF v_antiguedad < 10 THEN
            v_nom_user := v_nom_user || 'X';
        END IF;

        -- logica del apellido
        CASE r.id_estado_civil
            WHEN 10 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,2);
            WHEN 60 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,2);
            WHEN 20 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,1) || SUBSTR(r.appaterno_emp,-1);
            WHEN 30 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,1) || SUBSTR(r.appaterno_emp,-1);
            ELSE v_letras_ap := SUBSTR(r.appaterno_emp,-2);
        END CASE;

        -- formateo de la clave
        v_clave_user := SUBSTR(r.numrun_emp,3,1) ||
                        (EXTRACT(YEAR FROM r.fecha_nac) + 2) ||
                        SUBSTR(TO_CHAR(r.sueldo_base - 1),-3) ||
                        LOWER(v_letras_ap) ||
                        r.id_emp ||
                        TO_CHAR(v_f_proceso,'MMYYYY');

        -- insercion en la tabla 
        INSERT INTO USUARIO_CLAVE
        VALUES (
            r.id_emp,
            r.numrun_emp,
            r.dvrun_emp,
            TRIM(r.pnombre_emp || ' ' || r.snombre_emp || ' ' || r.appaterno_emp || ' ' || r.apmaterno_emp),
            v_nom_user,
            v_clave_user
        );

        v_contador := v_contador + 1;
    END LOOP;

    -- confirmacion del proceso con COMMIT + mensajes en consola
    IF v_contador = v_total_rango AND v_total_rango > 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO: '||v_contador||' registros.');
    ELSE
    -- uso de ROLLBACK en caso de una falla en el proceso
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: Rollback ejecutado por inconsistencia.');
    END IF;
-- agregamos un EXCEPTION para manejo de incidencias 
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR CRÍTICO: ' || SQLERRM);
END;
/

-- consulta verificadora para observar los datos de la tabla
SELECT * FROM USUARIO_CLAVE ORDER BY id_emp ASC;

