CLASS zbp_export_data DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_export_data.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR ExportData RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ExportData RESULT result.

    METHODS exportToFile FOR MODIFY
      IMPORTING keys FOR ACTION ExportData~exportToFile RESULT result.

    METHODS determineSemanticKey FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ExportData~determineSemanticKey.

    METHODS validateFileName FOR VALIDATE ON SAVE
      IMPORTING keys FOR ExportData~validateFileName.

    CONSTANTS:
      BEGIN OF gc_status,
        success TYPE c LENGTH 1 VALUE 'S',
        error   TYPE c LENGTH 1 VALUE 'E',
      END OF gc_status.

ENDCLASS.

CLASS zbp_export_data IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Check authorizations if needed
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_keys>).
      APPEND INITIAL LINE TO result ASSIGNING FIELD-SYMBOL(<ls_result>).
      <ls_result> = VALUE #(
        %tky                                = <ls_keys>-%tky
        %update                             = if_abap_behv=>auth-allowed
        %action-exportToFile                = if_abap_behv=>auth-allowed
        %delete                             = if_abap_behv=>auth-allowed ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    " Read entities
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        FIELDS ( status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_export_data).

    " Set features per instance
    result = VALUE #( FOR ls_export IN lt_export_data
                     ( %tky = ls_export-%tky
                       %action-exportToFile = COND #( WHEN ls_export-status = gc_status-success
                                                    THEN if_abap_behv=>fc-o-disabled
                                                    ELSE if_abap_behv=>fc-o-enabled )
                       %features-%update = COND #( 
                         WHEN ls_export-status = 'S'
                         THEN if_abap_behv=>fc-o-disabled
                         ELSE if_abap_behv=>fc-o-enabled )
                       %features-%delete = COND #( 
                         WHEN ls_export-status = 'S'
                         THEN if_abap_behv=>fc-o-disabled
                         ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD determineSemanticKey.
    " Read entities
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        FIELDS ( export_id ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_export_data).

    " Process only entries with initial semantic key
    DELETE lt_export_data WHERE export_id IS NOT INITIAL.
    CHECK lt_export_data IS NOT INITIAL.

    " Create UUID
    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    " Update entities
    MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        UPDATE FIELDS ( export_id )
        WITH VALUE #( FOR ls_export IN lt_export_data
                     ( %tky     = ls_export-%tky
                       export_id = lv_uuid ) ).
  ENDMETHOD.

  METHOD validateFileName.
    " Read entities
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        FIELDS ( filename ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_export_data).

    " Validate filename
    LOOP AT lt_export_data ASSIGNING FIELD-SYMBOL(<ls_export>).
      " Check if filename is empty
      IF <ls_export>-filename IS INITIAL.
        APPEND VALUE #( %tky = <ls_export>-%tky ) TO failed-exportdata.
        APPEND VALUE #( %tky = <ls_export>-%tky
                       %msg = new_message_with_text(
                         severity = if_abap_behv_message=>severity-error
                         text     = 'Filename cannot be empty' )
                       %element-filename = if_abap_behv=>mk-on ) TO reported-exportdata.
        CONTINUE.
      ENDIF.

      " Check if filename has .txt extension
      IF NOT matches( val = <ls_export>-filename regex = '.*\.txt$' ).
        APPEND VALUE #( %tky = <ls_export>-%tky ) TO failed-exportdata.
        APPEND VALUE #( %tky = <ls_export>-%tky
                       %msg = new_message_with_text(
                         severity = if_abap_behv_message=>severity-error
                         text     = 'Filename must have .txt extension' )
                       %element-filename = if_abap_behv=>mk-on ) TO reported-exportdata.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD exportToFile.
    DATA: lt_data   TYPE TABLE OF string,
          lv_string TYPE string.

    " 1. Đọc dữ liệu cần export
    SELECT vbeln,
           erdat,
           ernam,
           audat,
           auart,
           netwr,
           waerk
      FROM vbak
      INTO TABLE @DATA(lt_vbak)
      UP TO 100 ROWS.

    IF sy-subrc <> 0.
      " Xử lý khi không có dữ liệu
      MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
        ENTITY ExportData
          UPDATE FIELDS ( status message )
          WITH VALUE #( FOR key IN keys (
            %tky    = key-%tky
            status  = gc_status-error
            message = 'No data found to export' ) ).
      RETURN.
    ENDIF.

    " 2. Format dữ liệu để ghi file
    " Header
    APPEND 'Sales Document|Create Date|Created By|Document Date|Sales Doc Type|Net Value|Currency' TO lt_data.
    
    " Data rows
    LOOP AT lt_vbak ASSIGNING FIELD-SYMBOL(<ls_vbak>).
      lv_string = |{ <ls_vbak>-vbeln }| &&
                  '|' &&
                  |{ <ls_vbak>-erdat DATE = USER }| &&
                  '|' &&
                  |{ <ls_vbak>-ernam }| &&
                  '|' &&
                  |{ <ls_vbak>-audat DATE = USER }| &&
                  '|' &&
                  |{ <ls_vbak>-auart }| &&
                  '|' &&
                  |{ <ls_vbak>-netwr DECIMALS = 2 }| &&
                  '|' &&
                  |{ <ls_vbak>-waerk }|.
      APPEND lv_string TO lt_data.
    ENDLOOP.

    " 3. Ghi file
    TRY.
        " Đọc thông tin file name
        READ ENTITIES OF zi_export_data IN LOCAL MODE
          ENTITY ExportData
            FIELDS ( filename ) WITH CORRESPONDING #( keys )
          RESULT DATA(lt_export_data).

        DATA(ls_export) = lt_export_data[ 1 ].

        " Convert data sang xstring
        cl_bcs_convert=>string_table_to_xstring(
          EXPORTING
            it_string   = lt_data
            iv_codepage = '4110' "UTF-8
            iv_endian   = 'L'
          RECEIVING
            rv_xstring  = DATA(lv_xstring) ).

        " Tạo file service
        DATA(lo_file) = cl_bcs_file_handler=>create( ).

        " Ghi file
        lo_file->add_file(
          EXPORTING
            iv_content      = lv_xstring
            iv_extension    = 'txt'
            iv_name        = ls_export-filename ).

        " Lưu file
        lo_file->download( ).

        " Cập nhật status thành công
        MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
          ENTITY ExportData
            UPDATE FIELDS ( status message )
            WITH VALUE #( FOR key IN keys (
              %tky    = key-%tky
              status  = gc_status-success
              message = |File { ls_export-filename } exported successfully| ) ).

    CATCH cx_root INTO DATA(lx_error).
        " Cập nhật status lỗi
        MODIFY ENTITIES OF zi_export_data IN LOCAL MODE
          ENTITY ExportData
            UPDATE FIELDS ( status message )
            WITH VALUE #( FOR key IN keys (
              %tky    = key-%tky
              status  = gc_status-error
              message = lx_error->get_text( ) ) ).
    ENDTRY.

    " 4. Trả về kết quả
    READ ENTITIES OF zi_export_data IN LOCAL MODE
      ENTITY ExportData
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_entity IN lt_result
                     ( %tky   = ls_entity-%tky
                       %param = ls_entity ) ).
  ENDMETHOD.

ENDCLASS. 