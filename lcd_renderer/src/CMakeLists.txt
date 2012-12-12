cmake_minimum_required(VERSION 2.8)

include_directories(.)

INCLUDE(FindPkgConfig)
pkg_check_modules(CAIRO REQUIRED cairo)
add_definitions(${CAIRO_CFLAGS})
link_libraries(${CAIRO_LDFLAGS})

pkg_check_modules(FREETYPE REQUIRED freetype2)
add_definitions(${FREETYPE_CFLAGS})
link_libraries(${FREETYPE_LDFLAGS})

add_executable(lcd_renderer lcd_renderer.c parson.c)