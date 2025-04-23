CLASS zbp_export_data DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_export_data.
  PRIVATE SECTION.
    METHODS exportToFile FOR MODIFY
      IMPORTING keys FOR ACTION ExportData~exportToFile RESULT result.
ENDCLASS.

CLASS zbp_export_data IMPLEMENTATION.

  METHOD exportToFile.
    DATA: lt_data TYPE TABLE OF string,
          lv_file TYPE string.
          
    " Read entities
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_export_data).

    " Process data and create file content
    LOOP AT lt_export_data INTO DATA(ls_export).
      " Format data and add to lt_data
      " ...
    ENDLOOP.

    " Use Cloud File Service to create file
    TRY.
        DATA(lo_file) = cl_web_http_utility=>encode_utf8( lt_data ).
        
        " Logic to save file to system
        " Update status and message
        MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
          ENTITY ExportData
            UPDATE FIELDS ( status message )
            WITH VALUE #( FOR key IN keys (
              %tky    = key-%tky
              status  = 'S'
              message = 'Export successful' ) ).

    CATCH cx_root INTO DATA(lx_error).
        " Handle error and update status
        MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
          ENTITY ExportData
            UPDATE FIELDS ( status message )
            WITH VALUE #( FOR key IN keys (
              %tky    = key-%tky 
              status  = 'E'
              message = lx_error->get_text( ) ) ).
    ENDTRY.

    " Return result
    result = VALUE #( FOR key IN keys ( %tky = key-%tky ) ).
  ENDMETHOD.

ENDCLASS. 