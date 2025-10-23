import { htmlSafe } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";
import loadScript from "discourse/lib/load-script";
import { resizeAllGridItems } from "../lib/gridupdate";
import PreviewsDetails from "./../components/previews-details";
import PreviewsThumbnail from "./../components/previews-thumbnail";
import PreviewsTilesThumbnail from "./../components/previews-tiles-thumbnail";

const PLUGIN_ID = "discourse-tc-topic-list-previews";

const sanitizeCssValue = (value, fallback) => {
  if (!value) {
    return fallback;
  }
  const sanitized = value.replace(/[^#%(),.\/\w\s-]/g, "");
  return sanitized.trim() || fallback;
};

const previewsTilesThumbnail = <template>
  <PreviewsTilesThumbnail @topic={{@topic}} />
</template>;

const previewsDetails = <template>
  <PreviewsDetails @topic={{@topic}} />
</template>;

export default apiInitializer("0.8", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const topicListPreviewsService = api.container.lookup(
    "service:topic-list-previews"
  );

  api.onPageChange(() => {
    loadScript(settings.theme_uploads.imagesloaded).then(() => {
      if (document.querySelector(".tiles-style")) {
        //eslint-disable-next-line no-undef
        imagesLoaded(
          document.querySelector(".tiles-style"),
          resizeAllGridItems()
        );
      }
    });
  });

  // Keep track of the last "step" of 400 pixels.
  let lastIndex = 0;

  // Some browsers do some strange things with off-screen images,
  // so we need to resize the grid items when we scroll.
  // Listen for scroll events.
  window.addEventListener("scroll", () => {
    // Calculate the current index (which 400-pixel block we are in)
    const currentIndex = Math.floor(window.scrollY / 400);
    // If we've moved into a new block, call the function.
    if (currentIndex !== lastIndex) {
      lastIndex = currentIndex;
      resizeAllGridItems();
    }
  });

  api.registerValueTransformer("topic-list-columns", ({ value: columns }) => {
    if (topicListPreviewsService.displayCardLayout) {
      columns.delete("activity");
      columns.delete("replies");
      columns.delete("views");
      columns.delete("posters");
      columns.delete("topic");
    }
    return columns;
  });
  api.registerValueTransformer("topic-list-item-mobile-layout", ({ value }) => {
    if (topicListPreviewsService.displayCardLayout) {
      // Force the desktop layout
      return false;
    }
    return value;
  });

  api.registerValueTransformer(
    "topic-list-item-class",
    ({ value, context }) => {
      if (topicListPreviewsService.displayTiles) {
        value.push("tiles-style");
      }
      if (topicListPreviewsService.displayGrid) {
        value.push("grid-style");
      }
      if (topicListPreviewsService.displayCardLayout) {
        value.push("card-layout");
      }
      const configuredIcon =
        (settings.topic_list_thumbnail_icon || "").trim().length > 0;

      if (
        topicListPreviewsService.displayThumbnails &&
        (context.topic.thumbnails?.length > 0 ||
          (settings.topic_list_default_thumbnail_fallback &&
            settings.topic_list_default_thumbnail !== "") ||
          configuredIcon)
      ) {
        value.push("has-thumbnail");
      }
      if (
        siteSettings.topic_list_enable_thumbnail_colour_determination &&
        topicListPreviewsService.displayThumbnails
      ) {
        let red = context.topic.dominant_colour?.red || 0;
        let green = context.topic.dominant_colour?.green || 0;
        let blue = context.topic.dominant_colour?.blue || 0;

        //make 1 the minimum value to avoid total black
        red = red === 0 ? 1 : red;
        green = green === 0 ? 1 : green;
        blue = blue === 0 ? 1 : blue;

        let averageIntensity = context.topic.dominant_colour
          ? (red + green + blue) / 3
          : null;

        const cardBackgroundEnabled =
          settings.topic_list_dominant_color_background === "always" ||
          (topicListPreviewsService.displayCardLayout &&
            settings.topic_list_dominant_color_background === "tiles only");

        if (
          Object.keys(context.topic?.dominant_colour).length === 0 ||
          !cardBackgroundEnabled
        ) {
          value.push("no-background-colour");
        } else if (averageIntensity > 127) {
          value.push("dark-text");
        } else {
          value.push("white-text");
        }
      } else {
        value.push("no-background-colour");
      }

      return value;
    }
  );

  api.registerValueTransformer(
    "topic-list-item-style",
    ({ value, context }) => {
      if (
        siteSettings.topic_list_enable_thumbnail_colour_determination &&
        topicListPreviewsService.displayThumbnails &&
        (settings.topic_list_dominant_color_background === "always" ||
          (topicListPreviewsService.displayCardLayout &&
            settings.topic_list_dominant_color_background === "tiles only")) &&
        Object.keys(context.topic?.dominant_colour).length !== 0
      ) {
        let red = context.topic.dominant_colour?.red || 0;
        let green = context.topic.dominant_colour?.green || 0;
        let blue = context.topic.dominant_colour?.blue || 0;

        //make 1 the minimum value to avoid total black
        red = red === 0 ? 1 : red;
        green = green === 0 ? 1 : green;
        blue = blue === 0 ? 1 : blue;

        let newRgb = "rgb(" + red + "," + green + "," + blue + ")";

        value.push(htmlSafe(`background: ${newRgb};`));
      }
      if (topicListPreviewsService.displayGrid) {
        value.push(
          htmlSafe(
            `--tlp-grid-image-height: ${settings.topic_list_grid_image_height}px;`
          )
        );
        const background = sanitizeCssValue(
          settings.topic_list_grid_card_background,
          "#1a1f19"
        );
        value.push(htmlSafe(`--tlp-grid-card-background: ${background};`));
      }
      return value;
    }
  );

  api.registerValueTransformer("topic-list-class", ({ value }) => {
    if (topicListPreviewsService.displayGrid) {
      value.push("grid-style");
      value.push("card-layout");
    } else if (topicListPreviewsService.displayTiles) {
      value.push("tiles-style");
      value.push("card-layout");
      if (settings.topic_list_tiles_wide_format) {
        value.push("side-by-side");
      }
    }
    return value;
  });

  api.renderInOutlet(
    "topic-list-before-link",
    <template>
      {{#unless topicListPreviewsService.displayTiles}}
        {{#unless topicListPreviewsService.displayGrid}}
          {{#if topicListPreviewsService.displayThumbnails}}
            <div class="topic-thumbnail">
              <PreviewsThumbnail
                @tiles={{false}}
                @topic={{@outletArgs.topic}}
              />
            </div>
          {{/if}}
        {{/unless}}
      {{/unless}}
    </template>
  );

  api.registerValueTransformer("topic-list-item-expand-pinned", ({ value }) => {
    if (
      !topicListPreviewsService.displayCardLayout &&
      topicListPreviewsService.displayExcerpts
    ) {
      return true;
    }
    return value; // Return default value
  });

  api.registerValueTransformer("topic-list-columns", ({ value: columns }) => {
    const cardLayoutActive = topicListPreviewsService.displayCardLayout;

    if (cardLayoutActive && topicListPreviewsService.displayThumbnails) {
      columns.add(
        "previews-thumbnail",
        { item: previewsTilesThumbnail },
        { before: "topic" }
      );
    }
    if (cardLayoutActive) {
      columns.add(
        "previews-details",
        { item: previewsDetails },
        { after: "topic" }
      );
    }
    return columns;
  });

  api.modifyClass("component:search-result-entries", {
    pluginId: PLUGIN_ID,
    tagName: "div",
    classNameBindings: ["thumbnailGrid:thumbnail-grid"],

    thumbnailGrid() {
      return siteSettings.topic_list_search_previews_enabled;
    },
  });

  api.modifyClass("component:search-result-entry", {
    pluginId: PLUGIN_ID,

    thumbnailGrid() {
      return siteSettings.topic_list_search_previews_enabled;
    },
  });
});
