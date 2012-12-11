#include <cairo.h>
#include <cairo-ft.h>

#include <ft2build.h>
#include FT_FREETYPE_H

#include <stdio.h>

FT_Library ft_lib;

void lcd_draw_progress_bar(cairo_t *ctx, float x, float y, float width, float height, float progress)
{
  cairo_rectangle(ctx, x, y, width, height);
  cairo_set_source_rgb(ctx, 0.0, 0.0, 0.0);
  cairo_fill(ctx);

  // invert the progress since we are drawing white box
  if (progress < 0)
    progress = 0;
  else if (progress > 1)
    progress = 1;
  progress = 1 - progress;
  width -= 2;
  float white_width = width * progress;
  x = (x + 1) + width - white_width;

  cairo_rectangle(ctx, x, y + 1, white_width, height - 2);
  cairo_set_source_rgb(ctx, 1.0, 1.0, 1.0);
  cairo_fill(ctx);
}

int main(int argc, char *argv[])
{
  int error;

  error = FT_Init_FreeType(&ft_lib);
  if (error)
  {
    fprintf(stderr, "Failed to init freetype2\n");
    exit(-1);
  }

  FT_Face ftMetaWatch;
  cairo_font_face_t *ffMetaWatch;

  error = FT_New_Face(ft_lib, "./metawatch_8pt.ttf", 0, &ftMetaWatch);
  if (error)
  {
    fprintf(stderr, "Failed to load font\n");
    exit(-1);
  }

  ffMetaWatch = cairo_ft_font_face_create_for_ft_face(ftMetaWatch, 0);

  cairo_surface_t *cs;
  cs = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 256, 64);

  cairo_t *ctx;
  ctx = cairo_create(cs);

  cairo_rectangle(ctx, 0.0, 0.0, 256, 64);
  cairo_set_source_rgb(ctx, 1.0, 1.0, 1.0);
  cairo_fill(ctx);

  cairo_font_options_t *cfo;
  cfo = cairo_font_options_create();
  cairo_font_options_set_antialias(cfo, CAIRO_ANTIALIAS_NONE);
  cairo_set_font_options(ctx, cfo);
  cairo_set_font_face(ctx, ffMetaWatch);
  cairo_set_font_size(ctx, 8);
  
  cairo_move_to(ctx, 0.0, 8.0);
  cairo_set_source_rgb(ctx, 0, 0, 0);
  cairo_show_text(ctx, "CPU: 50%");

  lcd_draw_progress_bar(ctx, 60.0, 0.0, 127.0 - 60.0, 8.0, 0.5);

  cairo_move_to(ctx, 128.0, 8.0);
  cairo_set_source_rgb(ctx, 0, 0, 0);
  cairo_show_text(ctx, "MEM: 90% 11G");

  lcd_draw_progress_bar(ctx, 200.0, 0.0, 256.0 - 200.0, 8.0, 0.9);

  cairo_move_to(ctx, 0.0, 16.0);
  cairo_set_source_rgb(ctx, 0, 0, 0);
  cairo_show_text(ctx, "disk1: 92% 33G");

  lcd_draw_progress_bar(ctx, 70.0, 9.0, 127.0 - 70.0, 8.0, 0.92);

  cairo_move_to(ctx, 0.0, 56.0);
  cairo_set_source_rgb(ctx, 0, 0, 0);
  cairo_show_text(ctx, "up 2 days, 23:48, 5 users, load: 1.33 1.34 1.40");

  cairo_move_to(ctx, 0.0, 64.0);
  cairo_set_source_rgb(ctx, 0, 0, 0);
  cairo_show_text(ctx, "2012/12/10 11:14PM // retina // Mac OS X 10.8 Mt. Lion");

  cairo_font_options_destroy(cfo);
  cairo_destroy(ctx);

  cairo_surface_write_to_png(cs, "1.png");
  cairo_surface_flush(cs);
  cairo_surface_destroy(cs);
  cairo_font_face_destroy(ffMetaWatch);
}
