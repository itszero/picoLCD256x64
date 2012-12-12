#include <cairo.h>
#include <cairo-ft.h>

#include <ft2build.h>
#include FT_FREETYPE_H

#include <stdio.h>
#include <stdbool.h>

#include "parson.h"

FT_Library ft_lib;

void lcd_draw_text(cairo_t *ctx, float x, float y, const char *str)
{
  cairo_move_to(ctx, x, y);
  cairo_set_source_rgb(ctx, 0, 0, 0);
  cairo_show_text(ctx, str);  
}

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

cairo_font_face_t *load_font_for_cairo(char *fname, int index)
{
  int error;
  FT_Face ftToLoad;

  error = FT_New_Face(ft_lib, fname, index, &ftToLoad);
  if (error)
  {
    fprintf(stderr, "lcd_renderer: Failed to load font\n");
    return NULL;
  }

  return cairo_ft_font_face_create_for_ft_face(ftToLoad, 0);
}

void init_libs()
{
  int error;

  error = FT_Init_FreeType(&ft_lib);
  if (error)
  {
    fprintf(stderr, "lcd_renderer: Failed to init freetype2\n");
    exit(-1);
  }
}

cairo_status_t write_png_stream_to_stdout(void *closure, const unsigned char *data, unsigned int length)
{
  if (fwrite(data, 1, length, stdout) == length)
    return CAIRO_STATUS_SUCCESS;
  else
    return CAIRO_STATUS_WRITE_ERROR;
}

void draw_image(cairo_t *ctx, JSON_Object *root)
{
  JSON_Array *layout = json_object_get_array(root, "layout");
  JSON_Object *values = json_object_get_object(root, "values");

  size_t layout_length = json_array_get_count(layout);
  fprintf(stderr, "lcd_renderer: layout has %zd objects\n", layout_length);
  for(size_t i=0;i<layout_length;i++)
  {
    JSON_Object *obj = json_array_get_object(layout, i);
    const char *type = json_object_get_string(obj, "type");
    fprintf(stderr, "lcd_renderer: [layout] obj #%zd - %s\n", i, type);
    if (strcmp(type, "text") == 0)
    {
      JSON_Array *origin = json_object_get_array(obj, "origin");
      float x = (float)json_array_get_number(origin, 0), y = (float)json_array_get_number(origin, 1);
      const char *value_key = json_object_get_string(obj, "value");
      const char *str = json_object_get_string(values, value_key);

      fprintf(stderr, "lcd_renderer: [layout] origin: (%.1f, %.1f) str: %s (key: %s)\n", x, y, str, value_key);
      lcd_draw_text(ctx, x, y, str);      
    }
    else if (strcmp(type, "progressbar") == 0)
    {
      JSON_Array *origin = json_object_get_array(obj, "origin");
      float x = (float)json_array_get_number(origin, 0), y = (float)json_array_get_number(origin, 1);
      JSON_Array *size = json_object_get_array(obj, "size");
      float w = (float)json_array_get_number(size, 0), h = (float)json_array_get_number(size, 1);
      const char *value_key = json_object_get_string(obj, "value");
      float prg = (float)json_object_get_number(values, value_key);

      fprintf(stderr, "lcd_renderer: [layout] origin: (%.1f, %.1f) size: (%.1f, %.1f) progress: %.1f (key: %s)\n", x, y, w, h, prg, value_key);
      lcd_draw_progress_bar(ctx, x, y, w, h, prg);
    }
  }
}

char* read_all_from_stdin()
{
  char buf[1024];
  char *content = malloc(sizeof(char) * 1024);
  content[0] = '\0';

  size_t sz = 1;
  while(fgets(buf, 1024, stdin))
  {
    char *old = content;
    sz += strlen(buf);
    content = realloc(content, sz);
    if (content == NULL)
    {
      fprintf(stderr, "lcd_renderer: Failed to reallocate more space for content\n");
      free(old);
      exit(-1);
    }
    strcat(content, buf);
  }

  return content;
}

int main(int argc, char *argv[])
{
  init_libs();

  char* strJSON = read_all_from_stdin();
  fprintf(stderr, "lcd_renderer: read %zd bytes JSON\n", strlen(strJSON));
  JSON_Value *valRoot = json_parse_string(strJSON);
  free(strJSON);
  if (valRoot == NULL)
  {
    fprintf(stderr, "lcd_renderer: Failed to parse JSON input\n");
    exit(-1);
  }
  JSON_Object *root = json_value_get_object(valRoot);

  cairo_font_face_t *ffMetaWatch = load_font_for_cairo("./metawatch_8pt.ttf", 0);
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

  draw_image(ctx, root);

  cairo_font_options_destroy(cfo);
  cairo_destroy(ctx);

  cairo_surface_write_to_png_stream(cs, write_png_stream_to_stdout, NULL);
  cairo_surface_flush(cs);
  cairo_surface_destroy(cs);
  cairo_font_face_destroy(ffMetaWatch);

  json_value_free(valRoot);
}