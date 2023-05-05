using UnityEditor;
using UnityEngine;

//该脚本用于Float和Range的默认值的绘制
namespace Scarecrow
{
    public class DefDrawer : MaterialPropertyDrawer
    {

        public DefDrawer()
        {
        }

        // 让其他类也可以调用这个DefDrawer的绘制，这个用来绘制label。
        public static void DrawLabel(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            Material mat = editor.target as Material;
            Shader shader = mat.shader;
            DrawLabel(position, prop, label, shader);
        }
        // 让其他类也可以调用这个DefDrawer的绘制，这个用来绘制label。
        public static void DrawLabel(Rect position, MaterialProperty prop, GUIContent label, Shader shader)
        {
            int index = shader.FindPropertyIndex(prop.name);
            bool notDefaultValue = false;

            // 先存一下原来的GUI颜色
            Color originGUIColor = GUI.color;
            int originLevel = EditorGUI.indentLevel;
            EditorGUI.indentLevel = 0;

            if (prop.type == MaterialProperty.PropType.Float || prop.type == MaterialProperty.PropType.Range)
            {
                float defaultValue = shader.GetPropertyDefaultFloatValue(index);
                notDefaultValue = prop.floatValue != defaultValue;
                label.text = label.text + " (默认:" + defaultValue + ")";
            }
            else if (prop.type == MaterialProperty.PropType.Int)
            {
                float defaultValue = shader.GetPropertyDefaultFloatValue(index);
                notDefaultValue = prop.intValue != defaultValue;
                label.text = label.text + " (默认:" + defaultValue + ")";
            }
            else if (prop.type == MaterialProperty.PropType.Vector)
            {
                Vector4 defaultValue = shader.GetPropertyDefaultVectorValue(index);
                notDefaultValue = (prop.vectorValue.x != defaultValue.x || prop.vectorValue.y != defaultValue.y || prop.vectorValue.z != defaultValue.z || prop.vectorValue.w != defaultValue.w);
                label.text = label.text + " (默认:" + defaultValue + ")";
            }

            if (notDefaultValue)
            {
                Color redColor = Color.red;
                ColorUtility.TryParseHtmlString("#f2583f", out redColor);
                GUI.color = redColor;
            }

            Rect labelRect = position;
            labelRect.x += originLevel * 15;
            labelRect.width = EditorGUIUtility.labelWidth;
            EditorGUI.LabelField(labelRect, label);

            GUI.color = originGUIColor;
            EditorGUI.indentLevel = originLevel;
        }

        // 让其他类也可以调用这个DefDrawer的绘制。
        public static void Draw(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            Material mat = editor.target as Material;
            Shader shader = mat.shader;

            if (prop.type == MaterialProperty.PropType.Texture || prop.type == MaterialProperty.PropType.Color)
            {
                Debug.LogError("[Def]这个标签不支持Tex类型和Color类型！(shader:" + shader.name + ", property:" + prop.name + ")");
                editor.DefaultShaderProperty(prop, label.text);
                return;
            }

            // 先绘制一遍，这一遍是为了让float原来在Label上的鼠标拖动功能保留下来
            editor.DefaultShaderProperty(position, prop, " ");

            DrawLabel(position, prop, label, shader);
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            Draw(position, prop, label, editor);
        }
    }
}