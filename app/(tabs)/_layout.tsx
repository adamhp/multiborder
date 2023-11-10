import FontAwesome from '@expo/vector-icons/FontAwesome';
import { Link, Tabs } from 'expo-router';
import { Pressable, View, useColorScheme, Text } from 'react-native';
import { useRecoilValue } from 'recoil';
import { imagesState } from '../state';
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
  const images = useRecoilValue(imagesState);
  return (
    <Tabs>
      <Tabs.Screen
        name='index'
        options={{
          title: images.length === 0 ? 'Select' : 'Preview',
          tabBarLabel: ({ focused }) => (
            <TabBarLabel text={images.length === 0 ? 'Select' : 'Preview'} />
          ),
          tabBarIcon: ({ color }) => <TabBarIcon name='photo' color={color} />,
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
        }}
      />
    </Tabs>
  );
}
