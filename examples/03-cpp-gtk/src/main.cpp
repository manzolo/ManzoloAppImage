// Minimal GTK3 application packaged as an AppImage.
//
// Demonstrates the traditional AppImage case: a native binary that links
// against GTK and a chain of .so dependencies (libgtk-3, libgdk-3, libgio,
// libglib, libpango, libcairo, libX11, ...). linuxdeploy + the gtk plugin
// gather them all into AppDir/usr/lib at build time.

#include <gtk/gtk.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {

const char *kAppId    = "io.github.manzolo.hellocpp";
const char *kTitle    = "Hello C++ (AppImage)";
const char *kSubtitle = "GTK3 GUI packaged with linuxdeploy-plugin-gtk";

void on_click(GtkButton *button, gpointer user_data) {
    auto *label = static_cast<GtkLabel *>(user_data);
    static int clicks = 0;
    ++clicks;
    char buf[64];
    std::snprintf(buf, sizeof(buf), "Clicks: %d", clicks);
    gtk_label_set_text(label, buf);
    (void)button;
}

void activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    GtkWidget *window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), kTitle);
    gtk_window_set_default_size(GTK_WINDOW(window), 420, 220);

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_widget_set_margin_top(box, 24);
    gtk_widget_set_margin_bottom(box, 24);
    gtk_widget_set_margin_start(box, 24);
    gtk_widget_set_margin_end(box, 24);
    gtk_container_add(GTK_CONTAINER(window), box);

    GtkWidget *title = gtk_label_new(nullptr);
    char heading[128];
    std::snprintf(heading, sizeof(heading),
                  "<span size='x-large' weight='bold'>%s</span>", kTitle);
    gtk_label_set_markup(GTK_LABEL(title), heading);
    gtk_box_pack_start(GTK_BOX(box), title, FALSE, FALSE, 0);

    GtkWidget *subtitle = gtk_label_new(kSubtitle);
    gtk_label_set_line_wrap(GTK_LABEL(subtitle), TRUE);
    gtk_box_pack_start(GTK_BOX(box), subtitle, FALSE, FALSE, 0);

    GtkWidget *counter = gtk_label_new("Clicks: 0");
    gtk_box_pack_start(GTK_BOX(box), counter, FALSE, FALSE, 0);

    GtkWidget *button = gtk_button_new_with_label("Click me");
    g_signal_connect(button, "clicked", G_CALLBACK(on_click), counter);
    gtk_box_pack_start(GTK_BOX(box), button, FALSE, FALSE, 0);

    GtkWidget *quit = gtk_button_new_with_label("Quit");
    g_signal_connect_swapped(quit, "clicked", G_CALLBACK(gtk_widget_destroy), window);
    gtk_box_pack_start(GTK_BOX(box), quit, FALSE, FALSE, 0);

    // Allow scripted smoke testing: close the window after SMOKE_TEST_MS ms.
    const char *smoke = std::getenv("SMOKE_TEST_MS");
    if (smoke != nullptr && std::strlen(smoke) > 0) {
        guint ms = static_cast<guint>(std::atoi(smoke));
        if (ms > 0) {
            g_timeout_add(ms,
                          [](gpointer w) -> gboolean {
                              gtk_widget_destroy(GTK_WIDGET(w));
                              return G_SOURCE_REMOVE;
                          },
                          window);
        }
    }

    gtk_widget_show_all(window);
}

}  // namespace

int main(int argc, char **argv) {
    // G_APPLICATION_DEFAULT_FLAGS was added in GLib 2.74; use the older
    // spelling so this compiles on Ubuntu 22.04 (GLib 2.72).
    GtkApplication *app = gtk_application_new(kAppId, G_APPLICATION_FLAGS_NONE);
    g_signal_connect(app, "activate", G_CALLBACK(activate), nullptr);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
