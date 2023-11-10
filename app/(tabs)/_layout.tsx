import FontAwesome from '@expo/vector-icons/FontAwesome';
import { Link, Tabs } from 'expo-router';
import { Pressable, View, useColorScheme, Text } from 'react-native';
import { useRecoilState, useRecoilValue } from 'recoil';
import { imagesState, settingsState } from '../state';
import clsx from 'clsx';

/**
 * You can explore the built-in icon families and icons on the web at https://icons.expo.fyi/
 */
function TabBarIcon(props: {
  name: React.ComponentProps<typeof FontAwesome>['name'];
  color: string;
  isDisabled?: boolean;
}) {
  return (
    <Pressable disabled={props.isDisabled}>
      <FontAwesome
        size={20}
        style={{ opacity: props.isDisabled ? 0.25 : 1, marginBottom: -3 }}
        {...props}
      />
    </Pressable>
  );
}

function TabBarLabel(props: { text: string; isDisabled?: boolean }) {
  return (
    <Text
      className={clsx('text-xs font-space', {
        'text-zinc-800': props.isDisabled,
        'text-zinc-200': !props.isDisabled,
      })}
    >
      {props.text}
    </Text>
  );
}

export default function TabLayout() {
  const [settings, setSettings] = useRecoilState(settingsState);
  const images = useRecoilValue(imagesState);
  return (
    <Tabs>
      <Tabs.Screen
        name='index'
        listeners={{
          tabPress: (e) => {
            setSettings((settings) => ({
              ...settings,
              desiredSize: 200,
            }));
          },
        }}
        options={{
          headerShown: false,
          title: images.length === 0 ? 'Select' : 'Preview',
          tabBarLabel: ({ focused }) => (
            <TabBarLabel text={images.length === 0 ? 'Select' : 'Preview'} />
          ),
          tabBarIcon: ({ color }) => <TabBarIcon name='photo' color={color} />,
        }}
      />
      <Tabs.Screen
        name='edit'
        listeners={{
          tabPress: (e) => {
            // Prevent default action
            if (images.length === 0) {
              e.preventDefault();
            }
          },
        }}
        options={{
          headerShown: false,
          title: 'Edit',
          tabBarLabel: ({ focused }) => (
            <TabBarLabel text='Edit' isDisabled={images.length === 0} />
          ),
          tabBarIcon: ({ color }) => (
            <TabBarIcon
              name='pencil'
              color={color}
              isDisabled={images.length === 0}
            />
          ),
        }}
      />
      <Tabs.Screen
        name='export'
        listeners={{
          tabPress: (e) => {
            // Prevent default action
            if (images.length === 0) e.preventDefault();
          },
        }}
        options={{
          headerShown: false,
          title: 'Export',
          tabBarLabel: ({ focused }) => (
            <TabBarLabel text='Export' isDisabled={images.length === 0} />
          ),
          tabBarIcon: ({ color }) => (
            <TabBarIcon
              name='share'
              color={color}
              isDisabled={images.length === 0}
            />
          ),
          headerRight: () => (
            <Link href='/modal' asChild>
              <Pressable>
                {({ pressed }) => (
                  <FontAwesome
                    name='info-circle'
                    size={24}
                    style={{
                      color: 'white',
                      marginRight: 15,
                      opacity: pressed ? 0.5 : 1,
                    }}
                  />
                )}
              </Pressable>
            </Link>
          ),
        }}
      />
    </Tabs>
  );
}

export function PageContainer({ children }: { children: React.ReactNode }) {
  return (
    <View className='relative flex-1 flex-col items-center justify-center p-2 mt-10'>
      {children}
    </View>
  );
}
