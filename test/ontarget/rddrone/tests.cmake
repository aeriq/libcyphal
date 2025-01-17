#
# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#

set(BOARD_NAME rddrone)
set(MCU_MANUFACTURER NXP)
set(MCU_FAMILY S32K1)
set(MCU_LINE S32K146)
set(MCU_FLASH_SIZE 128)
set(JLINK_DEVICE S32K146)
set(JLINK_DEVICE_RESET_DELAY_MILLIS 400)

set(ONTARGET_TEST_PATH ${CMAKE_SOURCE_DIR}/ontarget)

add_definitions(-DCPU_${MCU_LINE})

include_directories(
    ${ONTARGET_TEST_PATH}/${BOARD_NAME}/include
)

set(MCU_LINKER_SCRIPT "${ONTARGET_TEST_PATH}/${BOARD_NAME}/Project_Settings/Linker_Files/${MCU_LINE}_${MCU_FLASH_SIZE}_flash.ld")

set(USER_SOURCES "${ONTARGET_TEST_PATH}/${BOARD_NAME}/src/canfd.cpp"
                 "${ONTARGET_TEST_PATH}/${BOARD_NAME}/src/clocks_and_modes.c"
                 "${ONTARGET_TEST_PATH}/${BOARD_NAME}/src/LPUART.c"
                 "${ONTARGET_TEST_PATH}/${BOARD_NAME}/src/FTM.c"
)

set(BSP_SOURCES "${ONTARGET_TEST_PATH}/${BOARD_NAME}/Project_Settings/Startup_Code/startup_${MCU_LINE}.S"
                "${ONTARGET_TEST_PATH}/${BOARD_NAME}/Project_Settings/Startup_Code/system_${MCU_LINE}.c"
                "${ONTARGET_TEST_PATH}/${BOARD_NAME}/Project_Settings/Startup_Code/startup.c"
)

set(SOURCE_FILES ${USER_SOURCES} ${BSP_SOURCES})

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -T ${MCU_LINKER_SCRIPT}")

# +---------------------------------------------------------------------------+
# | BUILD TESTS ON-TARGET TESTING
# +---------------------------------------------------------------------------+

function(define_ontarget_unit_test ARG_TEST_NAME ARG_TEST_SOURCE ARG_NODE_ID)

    set(LOCAL_TEST_ELF "${ARG_TEST_NAME}.elf")
    set(LOCAL_TEST_HEX "${ARG_TEST_NAME}.hex")
    set(LOCAL_TEST_BIN "${ARG_TEST_NAME}.bin")

    add_executable(${LOCAL_TEST_ELF} ${ARG_TEST_SOURCE} ${SOURCE_FILES})

    target_link_libraries(${LOCAL_TEST_ELF} dsdl-regulated)

    target_compile_definitions(${LOCAL_TEST_ELF} PUBLIC -DLIBUAVCAN_TEST_NODE_ID=${ARG_NODE_ID})

    set_target_properties(${LOCAL_TEST_ELF}
                    PROPERTIES
                    LINK_DEPENDS ${MCU_LINKER_SCRIPT})

    add_custom_command(TARGET ${LOCAL_TEST_ELF} POST_BUILD
                    COMMAND ${CMAKE_OBJCOPY} -Oihex $<TARGET_FILE:${LOCAL_TEST_ELF}> ${CMAKE_CURRENT_BINARY_DIR}/${LOCAL_TEST_HEX}
                    COMMENT "${LOCAL_TEST_ELF} -> ${LOCAL_TEST_HEX}")

    add_custom_command(TARGET ${LOCAL_TEST_ELF} POST_BUILD
                    COMMAND ${CMAKE_OBJCOPY} -Obinary $<TARGET_FILE:${LOCAL_TEST_ELF}> ${CMAKE_CURRENT_BINARY_DIR}/${LOCAL_TEST_BIN}
                    COMMENT "${LOCAL_TEST_ELF} -> ${LOCAL_TEST_BIN}")

    set(JLINK_LOG_FILE ${ARG_TEST_NAME}_jlink.log)
    set(JLINK_HEX ${LOCAL_TEST_HEX})

    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ontarget/loadfile_swd.jlink
                   ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TEST_NAME}_loadfile_swd.jlink)

    add_custom_target(flashtest_${ARG_TEST_NAME}
                      COMMAND JLinkExe -CommanderScript ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TEST_NAME}_loadfile_swd.jlink
                      DEPENDS ${LOCAL_TEST_ELF}
                              ${CMAKE_CURRENT_BINARY_DIR}/${LOCAL_TEST_HEX}
                              ${CMAKE_CURRENT_BINARY_DIR}/${ARG_TEST_NAME}_loadfile_swd.jlink
                      BYPRODUCTS ${JLINK_LOG_FILE}
                      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                      COMMENT "Manual flashing command for ${ARG_TEST_NAME} test."
    )

endfunction()

define_ontarget_unit_test(test_telephone_a
                          ${CMAKE_CURRENT_SOURCE_DIR}/ontarget/rddrone/src/test_telephone.cpp
                          1)
define_ontarget_unit_test(test_telephone_b
                          ${CMAKE_CURRENT_SOURCE_DIR}/ontarget/rddrone/src/test_telephone.cpp
                          2)

