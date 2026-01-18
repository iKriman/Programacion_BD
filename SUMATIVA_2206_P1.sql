SET SERVEROUTPUT ON;

VARIABLE b_fecha_proceso VARCHAR2(10);
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE,'DD/MM/YYYY');

TRUNCATE TABLE USUARIO_CLAVE;

DECLARE
    v_f_proceso     DATE := TO_DATE(:b_fecha_proceso,'DD/MM/YYYY');
    v_nom_user      VARCHAR2(100);
    v_clave_user    VARCHAR2(100);
    v_antiguedad    NUMBER;
    v_letra_ec      CHAR(1);
    v_nombre_ec     VARCHAR2(50);
    v_letras_ap     VARCHAR2(2);
    v_total_rango   NUMBER;
    v_contador      NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_total_rango
    FROM EMPLEADO
    WHERE id_emp BETWEEN 100 AND 320;

    FOR r IN (
        SELECT *
        FROM EMPLEADO
        WHERE id_emp BETWEEN 100 AND 320
        ORDER BY id_emp
    ) LOOP

        -- estado civil 
        SELECT nombre_estado_civil
        INTO v_nombre_ec
        FROM ESTADO_CIVIL
        WHERE id_estado_civil = r.id_estado_civil;

        v_letra_ec := LOWER(SUBSTR(v_nombre_ec,1,1));

        -- antiguedad correcta
        v_antiguedad :=
            FLOOR(MONTHS_BETWEEN(v_f_proceso, r.fecha_contrato) / 12);

        -- nombre de usuario
        v_nom_user :=
            v_letra_ec ||
            UPPER(SUBSTR(r.pnombre_emp,1,3)) ||
            LENGTH(r.pnombre_emp) || '*' ||
            SUBSTR(r.sueldo_base,-1) ||
            r.dvrun_emp ||
            v_antiguedad;

        IF v_antiguedad < 10 THEN
            v_nom_user := v_nom_user || 'X';
        END IF;

        -- letras apellido
        CASE r.id_estado_civil
            WHEN 10 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,2);
            WHEN 60 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,2);
            WHEN 20 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,1) || SUBSTR(r.appaterno_emp,-1);
            WHEN 30 THEN v_letras_ap := SUBSTR(r.appaterno_emp,1,1) || SUBSTR(r.appaterno_emp,-1);
            ELSE v_letras_ap := SUBSTR(r.appaterno_emp,-2);
        END CASE;

        -- clave usuario
        v_clave_user :=
            SUBSTR(r.numrun_emp,3,1) ||
            (EXTRACT(YEAR FROM r.fecha_nac) + 2) ||
            SUBSTR(TO_CHAR(r.sueldo_base - 1),-3) ||
            LOWER(v_letras_ap) ||
            r.id_emp ||
            TO_CHAR(v_f_proceso,'MMYYYY');

        INSERT INTO USUARIO_CLAVE
        VALUES (
            r.id_emp,
            r.numrun_emp,
            r.dvrun_emp,
            r.pnombre_emp || ' ' || r.snombre_emp || ' ' ||
            r.appaterno_emp || ' ' || r.apmaterno_emp,
            v_nom_user,
            v_clave_user
        );

        v_contador := v_contador + 1;
    END LOOP;

    IF v_contador = v_total_rango THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Proceso exitoso: '||v_contador||' registros.');
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: rollback ejecutado.');
    END IF;
END;
/



-- Verificacion final
SELECT * FROM USUARIO_CLAVE ORDER BY id_emp ASC;
