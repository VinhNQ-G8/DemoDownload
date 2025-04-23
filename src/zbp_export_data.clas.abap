CLASS zbp_export_data DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_export_data.
  PRIVATE SECTION.
    METHODS exportToFile FOR MODIFY
      IMPORTING keys FOR ACTION ExportData~exportToFile RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ExportData RESULT result.
ENDCLASS.

CLASS zbp_export_data IMPLEMENTATION.

  METHOD get_instance_features.
    " Read entities
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        FIELDS ( status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_export_data).

    result = VALUE #( FOR ls_export IN lt_export_data
                     ( %tky = ls_export-%tky
                       %action-exportToFile = COND #( WHEN ls_export-status = 'S'
                                                    THEN if_abap_behv=>fc-o-disabled
                                                    ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD exportToFile.
    DATA: lt_data   TYPE TABLE OF string,
          lv_string TYPE string.

    " Read entities
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_export_data).

    " Process data and create file content
    LOOP AT lt_export_data INTO DATA(ls_export).
      " Format header
      lv_string = |Export ID: { ls_export-export_id }|.
      APPEND lv_string TO lt_data.
      
      lv_string = |Created by: { ls_export-created_by } at { ls_export-created_at }|.
      APPEND lv_string TO lt_data.
      
      lv_string = |Last changed by: { ls_export-last_changed_by } at { ls_export-last_changed_at }|.
      APPEND lv_string TO lt_data.
      
      " Add empty line as separator
      APPEND '' TO lt_data.
    ENDLOOP.

    " Use Cloud File Service to create file
    TRY.
        " Get file service
        DATA(lo_file_service) = cl_file_service=>create( ).
        
        " Convert data to xstring
        DATA(lv_xstring) = cl_web_http_utility=>encode_utf8( lt_data ).
        
        " Create file path
        DATA(lv_file_path) = |/tmp/{ ls_export-filename }|.
        
        " Write file
        lo_file_service->write_xstring(
          EXPORTING
            path     = lv_file_path
            data     = lv_xstring
        ).

        " Update status and message
        MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
          ENTITY ExportData
            UPDATE FIELDS ( status message )
            WITH VALUE #( FOR key IN keys (
              %tky    = key-%tky
              status  = 'S'
              message = |File exported successfully to { lv_file_path }| ) ).

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

    " Read changed data for result
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    " Return result
    result = VALUE #( FOR ls_entity IN lt_result
                     ( %tky   = ls_entity-%tky
                       %param = ls_entity ) ).
  ENDMETHOD.

ENDCLASS. 